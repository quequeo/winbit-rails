class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('RESEND_FROM_EMAIL', 'Winbit <onboarding@resend.dev>')
  layout "mailer"

  private

  def backoffice_url(path = '')
    host = ENV.fetch('APP_HOST', 'localhost:3000')
    protocol = Rails.env.production? ? 'https' : 'http'
    "#{protocol}://#{host}#{path}"
  end
end
