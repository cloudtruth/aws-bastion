require 'aws-sdk-iam'

class IamUtil

  def initialize(credentials)
    @client = Aws::IAM::Client.new(credentials: credentials)
    @resource = ::Aws::IAM::Resource.new(credentials: credentials)
  end

  def iam_user(username)
    @users ||= {}
    @users[username] ||= begin
      iam_user = @resource.user(username)
      if ! iam_user.exists?
        raise "No IAM user with username: #{username}"
      end
      iam_user
    end
  end

  def iam_group(groupname)
    @groups ||= {}
    @groups[groupname] ||= begin
      iam_group = @resource.group(groupname)
      # no exists? method, using the group resource for a non-group causes a raise
      iam_group
    end
  end

  def ssh_keys_for_user(username)
    public_keys = []

    iam_user(username)

    key_ids = @client.list_ssh_public_keys(user_name: username).ssh_public_keys.collect {|key| key.ssh_public_key_id}
    key_ids.each do |key_id|
      key = @client.get_ssh_public_key(user_name: username, ssh_public_key_id: key_id, encoding: "SSH").ssh_public_key
      if key.status == 'Active'
        public_keys << "#{key.ssh_public_key_body} #{key_id}"
      end
    end

    return public_keys
  end

  def groups_for_user(username)
    groups = iam_user(username).groups.collect(&:name)
    return groups
  end

  def users_for_group(groupname)
    users = iam_group(groupname).users.collect(&:name)
    return users
  end

end