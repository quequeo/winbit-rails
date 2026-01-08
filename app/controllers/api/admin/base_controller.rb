module Api
  module Admin
    class BaseController < ApplicationController
      before_action :authenticate_user!

      private

      def require_superadmin!
        return if current_user&.superadmin?
        render_error('Solo los Super Admins pueden realizar esta acción', status: :forbidden)
      end

      def render_error(message, status: :bad_request, details: nil)
        payload = { error: message }
        payload[:details] = details if details
        render json: payload, status: status
      end
    end
  end
end
