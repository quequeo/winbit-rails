source "https://rubygems.org"

ruby "3.3.9"

gem "rails", "~> 8.0.4"
gem "pg", "~> 1.1"
gem "devise"
gem "omniauth-google-oauth2"
gem "rack-cors", "~> 2.0"
gem "puma", ">= 5.0"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "dotenv-rails", "~> 2.8"
  gem "rspec-rails", "~> 7.0"
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "reek", require: false
end

gem "simplecov", "~> 0.22.0", groups: [:development, :test]

gem "resend", "~> 1.0"
