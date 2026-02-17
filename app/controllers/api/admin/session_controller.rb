module Api
  module Admin
    class SessionController < BaseController
      def show
        render json: {
          data: AdminSessionSerializer.new(current_user).as_json
        }
      end
    end
  end
end
