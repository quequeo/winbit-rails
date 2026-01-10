# frozen_string_literal: true

# Resend Configuration
# https://resend.com/docs/send-with-rails
Resend.api_key = ENV.fetch('RESEND_API_KEY', 'default_test_key')
