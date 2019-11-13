require 'aws-sdk-core'
require 'aws-sdk-iam'

class AssumeRole

  def initialize(account_id, role_name, duration_seconds: 900)
    @account_id = account_id
    @role_name = role_name
    @duration_seconds = duration_seconds
    @role_arn = "arn:aws:iam::#{@account_id}:role/#{@role_name}"
  end

  def assume
      sts = ::Aws::STS::Client.new

      resp = sts.assume_role({
                                 duration_seconds: @duration_seconds,
                                 role_session_name: "Atmos",
                                 role_arn: @role_arn
                             })
      return resp
  end

  def env(resp)
    process_env = {}
    process_env['AWS_ACCESS_KEY_ID'] = resp.credentials.access_key_id
    process_env['AWS_SECRET_ACCESS_KEY'] = resp.credentials.secret_access_key
    process_env['AWS_SESSION_TOKEN'] = resp.credentials.session_token
    process_env['AWS_SESSION_EXPIRATION'] = resp.credentials.expiration.to_s
    process_env
  end

  def exec(*command_list)
    system(env(assume), *command_list)
  end

end
