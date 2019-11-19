require 'usertool.rb'

describe Usertool do
  let(:cli) { described_class.new("") }

  describe "--help" do

    it "produces help text under standard width" do
      expect(cli.help).to be_line_width_for_cli("top")
      cli.class.recognised_subcommands.each do |sc|
        expect(sc.subcommand_class.new("").help).to be_line_width_for_cli(sc.names.first)
      end
    end

  end

  describe "--account" do

    it "is required" do
      expect { cli.run(%w(--role abc auth_exec echo)) }.to raise_error(Clamp::UsageError, /-a.*required/)
    end

  end

  describe "--role" do

    it "is required" do
      expect { cli.run(%w(--account 123 auth_exec echo)) }.to raise_error(Clamp::UsageError, /-r.*required/)
    end

  end

  describe "auth_exec" do

    describe "parameters" do

      it "are required" do
        expect { cli.run(%w(--account 123 --role abc auth_exec)) }.to raise_error(Clamp::UsageError, /COMMAND.*no value provided/)
      end

    end

    describe "execution" do

      it "calls AssumeRole with command" do
        stub = instance_double(AssumeRole)
        expect(AssumeRole).to receive(:new).with("123", "abc", {duration_seconds: 1000}).and_return(stub)
        expect(stub).to receive(:exec).with(*%w(one two))
        cli.run(%w(--account 123 --role abc --duration 1000 auth_exec one two))
      end

    end

  end

  describe "ssh_keys" do

    describe "parameters" do

      it "are required" do
        expect { cli.run(%w(--account 123 --role abc ssh_keys)) }.to raise_error(Clamp::UsageError, /SYSUSER.*no value provided/)
      end

    end

    describe "execution" do

      it "outputs the keys" do
        ar = instance_double(AssumeRole)
        iam = instance_double(IamUtil)
        su = instance_double(SystemUser)

        creds = {}
        expect(AssumeRole).to receive(:new).and_return(ar)
        expect(ar).to receive(:assume).and_return(creds)
        expect(IamUtil).to receive(:new).with(creds).and_return(iam)
        expect(SystemUser).to receive(:new).with("dude", description: "dude@foo.com").and_return(su)

        expect(iam).to receive(:groups_for_user).with("dude@foo.com").and_return(%w(ssh sudo))
        expect(iam).to receive(:ssh_keys_for_user).with("dude@foo.com").and_return(%w(key1 key2))
        expect(su).to receive(:upsert).with(allow_sudo: true)
        cli_args = %w(--account 123 --role abc ssh_keys --ssh_group ssh --sudo_group sudo --pattern [user]@foo.com dude)
        expect{cli.run(cli_args)}.to output(/key1\nkey2/).to_stdout.and output.to_stderr
      end

      it "creates nonsudo user" do
        ar = instance_double(AssumeRole)
        iam = instance_double(IamUtil)
        su = instance_double(SystemUser)

        creds = {}
        expect(AssumeRole).to receive(:new).and_return(ar)
        expect(ar).to receive(:assume).and_return(creds)
        expect(IamUtil).to receive(:new).with(creds).and_return(iam)
        expect(SystemUser).to receive(:new).with("dude", description: "dude@foo.com").and_return(su)

        expect(iam).to receive(:groups_for_user).with("dude@foo.com").and_return(%w(ssh sudo))
        expect(iam).to receive(:ssh_keys_for_user).with("dude@foo.com").and_return(%w(key1 key2))
        expect(su).to receive(:upsert).with(allow_sudo: false)
        cli_args = %w(--account 123 --role abc ssh_keys --ssh_group ssh --sudo_group realsudo --pattern [user]@foo.com dude)
        expect{cli.run(cli_args)}.to output(/key1\nkey2/).to_stdout.and output.to_stderr
      end

      it "outputs no keys and skips user creation if not in ssh group" do
        ar = instance_double(AssumeRole)
        iam = instance_double(IamUtil)

        creds = {}
        expect(AssumeRole).to receive(:new).and_return(ar)
        expect(ar).to receive(:assume).and_return(creds)
        expect(IamUtil).to receive(:new).with(creds).and_return(iam)

        expect(iam).to receive(:groups_for_user).with("dude@foo.com").and_return(%w())
        expect(iam).to receive(:ssh_keys_for_user).never
        expect(SystemUser).to receive(:new).never

        cli_args = %w(--account 123 --role abc ssh_keys --ssh_group ssh --sudo_group sudo --pattern [user]@foo.com dude)
        expect{cli.run(cli_args)}.to not_output.to_stdout.and output.to_stderr.and raise_error(SystemExit)
      end

      it "outputs no keys and skips user creation if no keys in iam" do
        ar = instance_double(AssumeRole)
        iam = instance_double(IamUtil)

        creds = {}
        expect(AssumeRole).to receive(:new).and_return(ar)
        expect(ar).to receive(:assume).and_return(creds)
        expect(IamUtil).to receive(:new).with(creds).and_return(iam)

        expect(iam).to receive(:groups_for_user).with("dude@foo.com").and_return(%w(ssh sudo))
        expect(iam).to receive(:ssh_keys_for_user).with("dude@foo.com").and_return(%w())
        expect(SystemUser).to receive(:new).never

        cli_args = %w(--account 123 --role abc ssh_keys --ssh_group ssh --sudo_group sudo --pattern [user]@foo.com dude)
        expect{cli.run(cli_args)}.to not_output.to_stdout.and output.to_stderr.and raise_error(SystemExit)
      end

    end

  end

  describe "create_users" do

    describe "execution" do

      it "creates users" do
        ar = instance_double(AssumeRole)
        iam = instance_double(IamUtil)

        creds = {}
        expect(AssumeRole).to receive(:new).and_return(ar)
        expect(ar).to receive(:assume).and_return(creds)
        expect(IamUtil).to receive(:new).with(creds).and_return(iam)

        expect(iam).to receive(:users_for_group).with("ssh1").and_return(%w(user1@foo.com user2@foo.com))
        expect(iam).to receive(:users_for_group).with("ssh2").and_return(%w(user2@foo.com user3@foo.com))
        %w(user1 user2 user3).each do |u|
          expect(iam).to receive(:ssh_keys_for_user).with("#{u}@foo.com").and_return(["key-#{u}"])
          su = instance_double(SystemUser)
          expect(SystemUser).to receive(:new).with(u, description: "#{u}@foo.com").and_return(su)
          expect(su).to receive(:upsert).with(allow_sudo: false)
        end

        cli_args = %w(--account 123 --role abc create_users --ssh_group ssh1 --ssh_group ssh2 --pattern [user]@foo.com)
        expect{cli.run(cli_args)}.to not_output.to_stdout.and output.to_stderr
      end

    end

  end

end
