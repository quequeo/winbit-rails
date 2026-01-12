class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env['omniauth.auth']
    unless auth.present?
      redirect_to("#{frontend_url}/login?error=auth_failed", allow_other_host: true)
      return
    end

    user = User.from_google_omniauth(auth)

    unless user
      redirect_to("#{frontend_url}/login?error=unauthorized", allow_other_host: true)
      return
    end

    sign_in(user)
    redirect_to("#{frontend_url}/dashboard", allow_other_host: true)
  end

  def failure
    redirect_to("#{frontend_url}/login?error=auth_failed", allow_other_host: true)
  end

  private

  # Where to redirect after login failure/success.
  # If not configured, default to the same host that handled the callback (works for local 3000
  # when serving the UI from Rails, and avoids hardcoding 5173).
  def frontend_url
    ENV['FRONTEND_URL'].presence || request.base_url
  end
end
