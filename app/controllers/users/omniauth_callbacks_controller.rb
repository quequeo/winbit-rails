class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env['omniauth.auth']
    unless auth.present?
      redirect_to("/login?error=auth_failed")
      return
    end

    user = User.from_google_omniauth(auth)

    unless user
      redirect_to("/login?error=unauthorized")
      return
    end

    sign_in(user)
    redirect_to("/")
  end

  def failure
    redirect_to("/login?error=auth_failed")
  end
end
