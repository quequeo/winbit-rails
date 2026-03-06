require 'rails_helper'

RSpec.describe "Users::Sessions", type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  describe "DELETE /users/sign_out" do
    it "returns no content status" do
      delete destroy_user_session_path
      expect(response).to have_http_status(:no_content)
    end

    it "handles sign out without errors" do
      expect { delete destroy_user_session_path }.not_to raise_error
    end

    it "signs out when user is signed in" do
      sign_in(admin, scope: :user)
      delete destroy_user_session_path
      expect(response).to have_http_status(:no_content)
      expect(controller.current_user).to be_nil
    end
  end
end
