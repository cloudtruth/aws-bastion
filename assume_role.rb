#!/usr/bin/env ruby

require 'clamp'
require 'aws-sdk-core'
require 'aws-sdk-iam'

Clamp do

  banner "Assumes the role in the given account"

  option ["-a", "--account"], "ACCOUNT", "the aws account the role to be assumed resides in", required: true
  option ["-r", "--role"], "ROLE", "the name of the role to assume in the aws account", required: true
  option ["-d", "--duration"], "DURATION", "the duration of the assumed role session", default: 900 do |a|
    Integer(a)
  end

  parameter "COMMAND ...", "the command to run", required: false

  def execute
    role_arn = "arn:aws:iam::#{account}:role/#{role}"
    sts = ::Aws::STS::Client.new

    resp = sts.assume_role({
        duration_seconds: duration,
        role_session_name: "Atmos",
        role_arn: role_arn
    })

    process_env = {}
    process_env['AWS_ACCESS_KEY_ID'] = resp.credentials.access_key_id
    process_env['AWS_SECRET_ACCESS_KEY'] = resp.credentials.secret_access_key
    process_env['AWS_SESSION_TOKEN'] = resp.credentials.session_token
    process_env['AWS_SESSION_EXPIRATION'] = resp.credentials.expiration.to_s

    system(process_env, *command_list)
  end
end
