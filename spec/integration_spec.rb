require 'aws-sdk-iam'
require 'net/ssh'
require 'sshkey'

describe "Integration" do

  let(:user_pattern) { ENV["BASTION_IAM_USER_PATTERN"] }
  let(:ssh_groups) { ENV["BASTION_SSH_GROUPS"].split.uniq }
  let(:sudo_groups) { ENV["BASTION_SUDO_GROUPS"].split.uniq }
  let(:all_groups) { (ssh_groups + sudo_groups).uniq }

  let(:host) { ENV["BASTION_HOST"] }
  let(:port) { ENV["BASTION_PORT"] }
  let(:client) { Aws::IAM::Client.new }
  let(:username) { random_name(8) }
  let(:key) { SSHKey.generate }

  def iamuser(sysuser)
    return user_pattern.gsub(/\[user\]/, username)
  end

  def create_iam_user(username, groups: [], ssh_public_key: nil)
    iam_user = iamuser(username)
    u = client.create_user(user_name: iam_user)
    groups.each {|g| client.add_user_to_group(user_name: iam_user, group_name: g) }
    if ssh_public_key
      client.upload_ssh_public_key(user_name: iam_user, ssh_public_key_body: ssh_public_key)
    end
    return u
  end

  def activate_user(username, groups: ssh_groups)
    create_iam_user(username, groups: groups, ssh_public_key: key.ssh_public_key)

    expect {
      ssh(username, private_keys: key.private_key)
    }.to raise_error(Net::SSH::Disconnect)

    ssh(username, private_keys: key.private_key)
  end

  def ssh(username, password: nil, private_keys: nil, &block)
    result = nil
    Net::SSH.start(host, username, port: port, verify_host_key: :never, non_interactive: true, password: password, key_data: Array(private_keys)) do |ssh|
      if block
        result = block.call(ssh)
      else
        result = ssh.exec!("hostname")
      end
    end
    return result
  end

  before(:each) do
    iam_client = Aws::IAM::Client.new # can't use client from let in an before
    existing_groups = iam_client.list_groups.groups.collect(&:group_name)
    (all_groups - existing_groups).each {|g| iam_client.create_group(group_name: g) }
  end

  describe "connections" do

    it "denies password connection" do
      create_iam_user(username)
      expect {
        ssh(username, password: "password")
      }.to raise_error(Net::SSH::AuthenticationFailed)
    end

    it "denies when user hasn't added key to iam" do
      create_iam_user(username, groups: ssh_groups)
      expect {
        ssh(username, private_keys: key.private_key)
      }.to raise_error(Net::SSH::Disconnect)
    end

    it "succeeds on second connect when user has key in iam" do
      create_iam_user(username, groups: ssh_groups, ssh_public_key: key.ssh_public_key)

      expect {
        ssh(username, private_keys: key.private_key)
      }.to raise_error(Net::SSH::Disconnect)

      response = ssh(username, private_keys: key.private_key)
      expect(response).to_not be_nil
    end

  end

  describe "ssh access" do

    it "can have ssh taken away" do
      activate_user(username, groups: ssh_groups)

      response = ssh(username, private_keys: key.private_key)
      expect(response).to_not be_nil

      ssh_groups.each {|g| client.remove_user_from_group(user_name: iamuser(username), group_name: g) }

      expect {
        ssh(username, private_keys: key.private_key)
      }.to raise_error(Net::SSH::Disconnect)
    end

  end

  describe "sudo access" do

    it "doesn't have sudo by default" do
      activate_user(username, groups: ssh_groups)

      response = ssh(username, private_keys: key.private_key) do |ssh|
        ssh.exec!("sudo whoami")
      end
      expect(response).to_not eq("root")
    end

    it "can be granted sudo" do
      activate_user(username, groups: all_groups)

      response = ssh(username, private_keys: key.private_key) do |ssh|
        ssh.exec!("sudo whoami")
      end
      expect(response.chomp).to eq("root")
    end

    it "can have sudo taken away" do
      activate_user(username, groups: all_groups)

      response = ssh(username, private_keys: key.private_key) do |ssh|
        ssh.exec!("sudo whoami")
      end
      expect(response.chomp).to eq("root")

      sudo_groups.each {|g| client.remove_user_from_group(user_name: iamuser(username), group_name: g) }

      response = ssh(username, private_keys: key.private_key) do |ssh|
        ssh.exec!("sudo whoami")
      end
      expect(response.chomp).to_not eq("root")
    end

  end

end
