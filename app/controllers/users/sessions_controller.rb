class Users::SessionsController < Devise::SessionsController
  # DELETE /users/sign_out
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))

    # Return JSON response for API
    render json: { message: 'Signed out successfully' }, status: :ok
  end
end
