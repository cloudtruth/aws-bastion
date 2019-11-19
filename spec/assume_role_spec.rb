require "assume_role"

describe AssumeRole do

  let(:obj) { described_class.new("123", "abc") }

  before(:all) do
    @orig_stub_responses = ::Aws.config[:stub_responses]
    ::Aws.config[:stub_responses] = true
  end

  after(:all) do
    ::Aws.config[:stub_responses] = @orig_stub_responses
  end

  before(:each) do
    @client = ::Aws::STS::Client.new(stub_responses: true)
    allow(::Aws::STS::Client).to receive(:new).and_return(@client)
  end

  describe "assume" do

    it "gets auth from aws" do
      @client.stub_responses(:assume_role)
      resp = obj.assume
      expect(@client.api_requests.size).to eq(1)
      expect(@client.api_requests.first[:params][:duration_seconds]).to eq(900)
      expect(@client.api_requests.first[:params][:role_session_name]).to eq("Bastion")
      expect(@client.api_requests.first[:params][:role_arn]).to eq("arn:aws:iam::123:role/abc")
      expect(resp.credentials.access_key_id).to_not be_nil
      expect(resp.credentials.secret_access_key).to_not be_nil
      expect(resp.credentials.session_token).to_not be_nil
      expect(resp.credentials.expiration).to_not be_nil
    end

  end

  describe "env" do

    it "generates env hash" do
      stub_resp = @client.stub_data(:assume_role)
      env = obj.env(stub_resp)
      expect(env['AWS_ACCESS_KEY_ID']).to eq(stub_resp.credentials.access_key_id)
      expect(env['AWS_SECRET_ACCESS_KEY']).to eq(stub_resp.credentials.secret_access_key)
      expect(env['AWS_SESSION_TOKEN']).to eq(stub_resp.credentials.session_token)
      expect(env['AWS_SESSION_EXPIRATION']).to eq(stub_resp.credentials.expiration.to_s)
    end

  end

  describe "exec" do

    it "runs a command with assumed env" do
      stub_resp = @client.stub_data(:assume_role)
      expect(obj).to receive(:assume).and_call_original
      expect(obj).to receive(:env).and_call_original
      expect(obj).to receive(:system).with(
          hash_including(*%w(AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SESSION_EXPIRATION)),
          "run", "me")
      obj.exec(*%w(run me))
    end

  end

end
