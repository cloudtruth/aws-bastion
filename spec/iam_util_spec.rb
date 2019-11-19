require "iam_util"
require "securerandom"
require "sshkey"

describe IamUtil do

  let(:iam_client) { Aws::IAM::Client.new }
  let(:iam_resource) { Aws::IAM::Resource.new }
  let(:obj) { described_class.new }

  describe "iam_user" do

    it "fetches an iam user" do
      u = random_name
      iam_client.create_user(user_name: u)
      user = obj.iam_user(u)
      expect(user.name).to eq(u)
    end

    it "fails if no user" do
      expect { obj.iam_user("notuser") }.to raise_error(RuntimeError, /No IAM user/)
    end

  end

  describe "iam_group" do

    it "fetches an iam group" do
      g = random_name
      iam_client.create_group(group_name: g)
      group = obj.iam_group(g)
      expect(group.name).to eq(g)
    end

    it "fails if no group" do
      expect { obj.iam_group("notgroup") }.to raise_error(RuntimeError, /No IAM group/)
    end

  end

  describe "groups_for_user" do

    it "gets the groups a user belongs to" do
      u = random_name
      iam_client.create_user(user_name: u)
      expect(obj.groups_for_user(u)).to eq([])

      g = random_name
      iam_client.create_group(group_name: g)
      iam_client.add_user_to_group(user_name: u, group_name: g)
      expect(obj.groups_for_user(u)).to eq([g])

      g2 = random_name
      iam_client.create_group(group_name: g2)
      iam_client.add_user_to_group(user_name: u, group_name: g2)
      expect(obj.groups_for_user(u)).to eq([g, g2])
    end

  end

  describe "users_for_group" do

    it "gets the users in a group" do
      g = random_name
      iam_client.create_group(group_name: g)
      expect(obj.users_for_group(g)).to eq([])

      u = random_name
      iam_client.create_user(user_name: u)
      iam_client.add_user_to_group(user_name: u, group_name: g)
      expect(obj.users_for_group(g)).to eq([u])

      u2 = random_name
      iam_client.create_user(user_name: u2)
      iam_client.add_user_to_group(user_name: u2, group_name: g)
      expect(obj.users_for_group(g)).to eq([u, u2])
    end

  end

  describe "ssh_keys_for_user" do

    it "gets a users active ssh keys" do
      u = random_name
      iam_client.create_user(user_name: u)
      expect(obj.ssh_keys_for_user(u).length).to eq(0)

      k = SSHKey.generate
      k_resp = iam_client.upload_ssh_public_key(user_name: u, ssh_public_key_body: k.ssh_public_key)
      expect(obj.ssh_keys_for_user(u).length).to eq(1)
      expect(obj.ssh_keys_for_user(u).first).to eq("#{k.ssh_public_key} #{k_resp.ssh_public_key.ssh_public_key_id}")

      k2 = SSHKey.generate
      k2_resp = iam_client.upload_ssh_public_key(user_name: u, ssh_public_key_body: k2.ssh_public_key)
      expect(obj.ssh_keys_for_user(u).length).to eq(2)
      expect(obj.ssh_keys_for_user(u).last).to eq("#{k2.ssh_public_key} #{k2_resp.ssh_public_key.ssh_public_key_id}")

      iam_client.update_ssh_public_key(user_name: u, ssh_public_key_id: k_resp.ssh_public_key.ssh_public_key_id, status: "Inactive")
      expect(obj.ssh_keys_for_user(u).length).to eq(1)
      expect(obj.ssh_keys_for_user(u).first).to eq("#{k2.ssh_public_key} #{k2_resp.ssh_public_key.ssh_public_key_id}")
    end

  end

end
