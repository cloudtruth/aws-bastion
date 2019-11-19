source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "2.6.5"

gem "clamp"
gem "aws-sdk-iam"

group :development, :test do
  gem "ruby-debug-ide"
  gem "debase"
end

group :test do
  gem "rspec"
  gem "sshkey"
  gem "net-ssh"
end
