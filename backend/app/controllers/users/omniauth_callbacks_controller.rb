class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  FRONTEND_URL = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')

  def google_oauth2
    user = User.from_google_omniauth(request.env['omniauth.auth'])

    unless user
      redirect_to("#{FRONTEND_URL}/login?error=unauthorized")
      return
    end

    sign_in(user)
    redirect_to("#{FRONTEND_URL}/dashboard")
  end

  def failure
    redirect_to("#{FRONTEND_URL}/login?error=auth_failed")
  end
end
