require 'rails_helper'

RSpec.describe "Users::Sessions", type: :request do
  describe "DELETE /users/sign_out" do
    it "returns no content status" do
      delete destroy_user_session_path
      expect(response).to have_http_status(:no_content)
    end

    it "handles sign out without errors" do
      expect { delete destroy_user_session_path }.not_to raise_error
    end
  end
end
