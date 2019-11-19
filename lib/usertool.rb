require 'clamp'
require 'assume_role'
require 'iam_util'
require 'system_user'

class Usertool < Clamp::Command
  banner "Utility commands for managing system users based on iam group membership"

  option ["-a", "--account"], "ACCOUNT", "the aws account to assume role into\n", required: true
  option ["-r", "--role"], "ROLE", "the role name to assume\n", required: true
  option ["-d", "--duration"], "DURATION", "the assumed role session duration\n", default: 900 do |a|
    Integer(a)
  end

  subcommand "auth_exec", "Runs the command after assuming role"  do
    banner "Runs the given command under an assumed role"

    parameter "COMMAND ...", "the command to run", required: true

    def execute
      ar = AssumeRole.new(account, role, duration_seconds: duration)
      ar.exec(*command_list)
    end

  end

  subcommand "ssh_keys", "Lists ssh public keys for a user" do

    banner "Given a system username, looks up the iam user to see if they have public\nkeys, and lists them in a form usable by the sshd AuthorizedKeys command"

    option ["-s", "--ssh_group"], "SSH_GROUP", "the IAM group where membership\ngrants ssh permissions", multivalued: true
    option ["-u", "--sudo_group"], "SUDO_GROUP", "the IAM group where membership\ngrants sudo permissions", multivalued: true
    option ["-p", "--pattern"], "PATTERN", "the pattern for generating iam\nusername\ne.g. [user]@mydomain.com", required: true

    parameter "SYSUSER", "the system username to\nlookup - passed by the sshd.conf\noption AuthorizedKeysCommand"

    def execute
      $stderr.puts "Starting auth key lookup"

      credentials = AssumeRole.new(account, role).assume
      iam = IamUtil.new(credentials)
      iam_username = pattern.gsub("[user]", sysuser)

      groups = iam.groups_for_user(iam_username)
      allow_ssh = ssh_group_list.any? {|g| groups.include?(g) }
      allow_sudo = sudo_group_list.any? {|g| groups.include?(g) }

      if allow_ssh
        ssh_public_keys = iam.ssh_keys_for_user(iam_username)
        if ssh_public_keys.size > 0
          SystemUser.new(sysuser, description: iam_username).upsert(allow_sudo: allow_sudo)
          $stderr.puts "Returning pubkeys to ssh"
          puts ssh_public_keys.join("\n")
        else
          $stderr.puts "No public keys"
          exit(1)
        end
      else
        $stderr.puts "User '#{iam_username}' not in any iam group: #{ssh_group_list.inspect}"
        exit(1)
      end
    end

  end


  subcommand "create_users", "Creates system users from authorized iam users"  do

    banner "Creates system users for all iam users in the iam ssh group"

    option ["-s", "--ssh_group"], "SSH_GROUP", "the IAM group where membership\ngrants ssh permissions", multivalued: true
    option ["-p", "--pattern"], "PATTERN", "the pattern for generating iam\nusername\ne.g. [user]@mydomain.com", required: true

    def execute
      $stderr.puts "Starting auth key lookup"

      credentials = AssumeRole.new(account, role).assume
      iam = IamUtil.new(credentials)

      iam_users = []
      ssh_group_list.each {|g|  iam_users.concat(iam.users_for_group(g)) }
      iam_users.uniq!

      iam_users.each do |iam_user|
        ssh_public_keys = iam.ssh_keys_for_user(iam_user)
        if ssh_public_keys.size > 0
          r = pattern.gsub("[user]", "(.*)")
          if Regexp.new(r) =~ iam_user
            sysuser = $1
            # ssh_keys command called from ssh AuthorizedKeysCommand will handle
            # setting of sudo rights, since this is a user preload, set to false
            # as extra safety
            SystemUser.new(sysuser, description: iam_user).upsert(allow_sudo: false)
          else
            $stderr.puts "Skipping user '#{iam_user}' as unable to match pattern '#{pattern}'"
          end
        else
          $stderr.puts "Skipping user creation as no public keys: #{iam_user}"
        end
      end
    end

  end

end
