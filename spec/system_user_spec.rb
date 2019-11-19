require "system_user"

describe SystemUser do

  around(:each) do |example|
    silence_stderr { example.run }
  end

  let(:username) { random_name(8) }

  describe "upsert" do

    it "creates a user without sudo" do
      obj = described_class.new(username, description: "#{username}@foo.com")

      expect(Dir.exists?("/home/#{username}")).to be_falsey

      obj.upsert(allow_sudo: false)
      expect(Dir.exists?("/home/#{username}")).to be_truthy
      expect(Dir.exists?("/home/#{username}/.ssh")).to be_truthy
      expect(sprintf("%o", File.stat("/home/#{username}/.ssh").mode)).to match(/0700$/)
      expect(Dir.exists?("/home/#{username}/.ssh/authorized_keys")).to be_falsey
      expect(Etc.getgrnam(obj.unix_group).mem).to include(username)
      expect(Etc.getgrnam(obj.ssh_group).mem).to include(username)
      expect(Etc.getgrnam(obj.sudo_group).mem).to_not include(username)
    end

    it "creates a user with sudo" do
      obj = described_class.new(username, description: "#{username}@foo.com")

      expect(Dir.exists?("/home/#{username}")).to be_falsey

      obj.upsert(allow_sudo: true)
      expect(Dir.exists?("/home/#{username}")).to be_truthy
      expect(Dir.exists?("/home/#{username}/.ssh")).to be_truthy
      expect(sprintf("%o", File.stat("/home/#{username}/.ssh").mode)).to match(/0700$/)
      expect(File.exists?("/home/#{username}/.ssh/authorized_keys")).to be_falsey
      expect(Etc.getgrnam(obj.unix_group).mem).to include(username)
      expect(Etc.getgrnam(obj.ssh_group).mem).to include(username)
      expect(Etc.getgrnam(obj.sudo_group).mem).to include(username)
    end

    it "updates a user to have sudo" do
      obj = described_class.new(username, description: "#{username}@foo.com")

      obj.upsert(allow_sudo: false)
      expect(Etc.getgrnam(obj.sudo_group).mem).to_not include(username)

      obj.upsert(allow_sudo: true)
      expect(Etc.getgrnam(obj.sudo_group).mem).to include(username)
    end

    it "updates a user to remove sudo" do
      obj = described_class.new(username, description: "#{username}@foo.com")

      obj.upsert(allow_sudo: true)
      expect(Etc.getgrnam(obj.sudo_group).mem).to include(username)

      obj.upsert(allow_sudo: false)
      expect(Etc.getgrnam(obj.sudo_group).mem).to_not include(username)
    end

    it "updates a user keeping their files" do
      obj = described_class.new(username, description: "#{username}@foo.com")

      obj.upsert(allow_sudo: false)
      expect(File.exists?("/home/#{username}/todo")).to be_falsey
      File.write("/home/#{username}/todo", "I put my own file")
      expect(File.exists?("/home/#{username}/todo")).to be_truthy

      obj.upsert(allow_sudo: false)
      expect(File.exists?("/home/#{username}/todo")).to be_truthy
    end


    it "updates a user to remove authorized_keys" do
      obj = described_class.new(username, description: "#{username}@foo.com")

      obj.upsert(allow_sudo: false)
      expect(File.exists?("/home/#{username}/.ssh/authorized_keys")).to be_falsey
      File.write("/home/#{username}/.ssh/authorized_keys", "I put my own keys")
      expect(File.exists?("/home/#{username}/.ssh/authorized_keys")).to be_truthy

      obj.upsert(allow_sudo: false)
      expect(File.exists?("/home/#{username}/.ssh/authorized_keys")).to be_falsey
    end

  end

end
