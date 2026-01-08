module Api
  module Admin
    class SessionController < BaseController
      def show
        render json: {
          data: {
            email: current_user.email,
            superadmin: current_user.superadmin?
          }
        }
      end
    end
  end
end
