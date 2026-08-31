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
gem "roo", "~> 2.10"
gem "rubyzip", "~> 2.3"

# Monthly investor report PDF generation (see app/services/investor_monthly_report_pdfs).
gem "wicked_pdf", "~> 2.8"
# Ships the wkhtmltopdf binary itself (Heroku-22/24 compatible) and points
# wicked_pdf at it automatically - no separate Heroku buildpack needed.
# Locally (e.g. Windows dev machines) it's inert; install wkhtmltopdf
# yourself and set WKHTMLTOPDF_BINARY, or put it on PATH (see
# config/initializers/wicked_pdf.rb).
gem "wkhtmltopdf-heroku", "3.0.0"
