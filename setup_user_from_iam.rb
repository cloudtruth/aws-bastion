#!/usr/bin/env ruby

require 'etc'
require 'open3'
require 'fileutils'
require 'securerandom'
require 'clamp'
require 'aws-sdk-core'
require 'aws-sdk-iam'

Clamp do

  include FileUtils

  banner "Given a system username, looks up the iam user to see if they have public\nkeys, and lists them in a form usable by the sshd AuthorizedKeys command"

  option ["-a", "--account"], "ACCOUNT", "the aws account the role to be\nassumed resides in", required: true
  option ["-r", "--role"], "ROLE", "the name of the role to assume in\nthe aws account", required: true
  option ["-d", "--duration"], "DURATION", "the duration of the assumed\nrole session", default: 900 do |a|
    Integer(a)
  end

  option ["-s", "--ssh_group"], "SSH_GROUP", "the IAM group where membership\ngrants ssh permissions", multivalued: true
  option ["-u", "--sudo_group"], "SUDO_GROUP", "the IAM group where membership\ngrants sudo permissions", multivalued: true
  option ["-p", "--iam_user_pattern"], "IAM_USER_PATTERN", "the pattern for generating iam\nusername\ne.g. {user}@mydomain.com", required: true

  parameter "SYSUSER", "the system username to\nlookup - passed by the sshd_config\noption AuthorizedKeysCommand"

  def execute
    $stderr.puts "Starting auth key lookup"

    credentials = nil
    if account && role
      credentials = assume_role(account: account, role: role)
    elsif ENV['AWS_ACCESS_KEY_ID'].nil? || ENV['AWS_SECRET_ACCESS_KEY'].nil?
      raise Clamp::UsageError, "No assume role details were given and there are no aws keys in the environment"
    end

    client = Aws::IAM::Client.new(credentials: credentials)
    resource = ::Aws::IAM::Resource.new(credentials: credentials)

    iam_username = iam_user_pattern.gsub("{user}", sysuser)
    ssh_public_keys = lookup_ssh_keys_from_iam(client: client, resource: resource, iam_username: iam_username, system_username: sysuser)

    puts ssh_public_keys.join("\n")
  end

  def assume_role(account:, role:)
    role_arn = "arn:aws:iam::#{account}:role/#{role}"
    sts = ::Aws::STS::Client.new

    resp = sts.assume_role({
                               duration_seconds: duration,
                               role_session_name: "Atmos",
                               role_arn: role_arn
                           })

    return resp
  end

  def lookup_ssh_keys_from_iam(client:, resource:, iam_username:, system_username:)
    public_keys = []

    iam_user = resource.user(iam_username)
    if ! iam_user.exists?
      raise "No IAM user with username: #{iam_username}"
    end

    groups = iam_user.groups.collect(&:name)

    allow_ssh = ssh_group_list.any? {|g| groups.include?(g) }
    allow_sudo = sudo_group_list.any? {|g| groups.include?(g) }

    if allow_ssh
      key_ids = client.list_ssh_public_keys(user_name: iam_username).ssh_public_keys.collect {|key| key.ssh_public_key_id}
      key_ids.each do |key_id|
        key = client.get_ssh_public_key(user_name: iam_username, ssh_public_key_id: key_id, encoding: "SSH").ssh_public_key
        if key.status == 'Active'
          public_keys << "#{key.ssh_public_key_body} #{key_id}"
        end
      end

      if public_keys.size > 0
        upsert_system_user(iam_username: iam_username, system_username: system_username, allow_sudo: allow_sudo)
      end
    end

    return public_keys
  end

  def upsert_system_user(iam_username:, system_username:, allow_sudo:)
    $stderr.puts "Ensuring system user '#{system_username}' for IAM user '#{iam_username}'"

    unix_group = "iam"
    sudo_group = "iam-sudo"
    # group named ssh is needed for some linux flavors
    ssh_group = "ssh"

    system "groupadd -f #{unix_group}" || fail("Failed to add group")
    system "groupadd -f #{ssh_group}" || fail("Failed to add group")
    system "groupadd -f #{sudo_group}" || fail("Failed to add group")

    # Allow passwdless sudo for members of the group
    File.write("/etc/sudoers.d/95-iam-users", "%#{sudo_group} ALL=(ALL) NOPASSWD:ALL")

    useradd_groups = "#{unix_group}"
    useradd_groups << ",#{ssh_group}"
    useradd_groups << ",#{sudo_group}" if allow_sudo

    system_user_exists = Etc.getpwnam(system_username) rescue nil
    if system_user_exists
      system "usermod -G #{useradd_groups} #{system_username}" || fail("Failed to modify user groups")
    else
      $stderr.puts "Adding new system user: #{system_username}"
      system "useradd -m -p #{SecureRandom.hex} -s /bin/bash -G #{useradd_groups} -c '#{iam_username}' #{system_username}" || fail("Failed to add user")
    end

    $stderr.puts "Setting up ssh dir"

    home_dir = Etc.getpwnam(system_username).dir
    mkdir_p("#{home_dir}/.ssh")
    chmod(0700, "#{home_dir}/.ssh")
    rm_f("#{home_dir}/.ssh/authorized_keys")

  end

end
