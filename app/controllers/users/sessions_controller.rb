class Users::SessionsController < Devise::SessionsController
  # DELETE /users/sign_out
  def destroy
    if user_signed_in?
      sign_out(current_user)
    end

    head :no_content
  end

  protected

  def respond_to_on_destroy
    head :no_content
  end
end
