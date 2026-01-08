class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  private

  # Where to redirect after login failure/success.
  # If not configured, default to the same host that handled the callback (works for local 3000
  # when serving the UI from Rails, and avoids hardcoding 5173).
  def frontend_url
    ENV['FRONTEND_URL'].presence || request.base_url
  end

  def google_oauth2
    user = User.from_google_omniauth(request.env['omniauth.auth'])

    unless user
      redirect_to("#{frontend_url}/login?error=unauthorized")
      return
    end

    sign_in(user)
    redirect_to("#{frontend_url}/dashboard")
  end

  def failure
    redirect_to("#{frontend_url}/login?error=auth_failed")
  end
end
