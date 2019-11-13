
require 'etc'
require 'open3'
require 'fileutils'
require 'securerandom'

class SystemUser

  include FileUtils

  attr_accessor :unix_group, :sudo_group, :ssh_group

  def initialize(username, description: "")
    @username = username
    @description = description

    self.unix_group = "iam"
    self.sudo_group = "iam-sudo"
    # group named ssh is needed for some linux flavors
    self.ssh_group = "ssh"
  end

  def upsert(allow_sudo: false)
    $stderr.puts "Ensuring system user '#{@username}' (#{@description})'"


    system "groupadd -f #{unix_group}" || fail("Failed to add group")
    system "groupadd -f #{ssh_group}" || fail("Failed to add group")
    system "groupadd -f #{sudo_group}" || fail("Failed to add group")

    # Allow passwdless sudo for members of the group
    File.write("/etc/sudoers.d/95-iam-users", "%#{sudo_group} ALL=(ALL) NOPASSWD:ALL")

    useradd_groups = "#{unix_group}"
    useradd_groups << ",#{ssh_group}"
    useradd_groups << ",#{sudo_group}" if allow_sudo

    system_user_exists = Etc.getpwnam(@username) rescue nil
    if system_user_exists
      system "usermod -G #{useradd_groups} #{@username}" || fail("Failed to modify user groups")
    else
      $stderr.puts "Adding new system user: #{@username}"
      system "useradd -m -p #{SecureRandom.hex} -s /bin/bash -G #{useradd_groups} -c '#{@description}' #{@username}" || fail("Failed to add user")
    end

    $stderr.puts "Setting up ssh dir"

    home_dir = Etc.getpwnam(@username).dir
    mkdir_p("#{home_dir}/.ssh")
    chmod(0700, "#{home_dir}/.ssh")
    rm_f("#{home_dir}/.ssh/authorized_keys")

  end

end
