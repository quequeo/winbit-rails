module Api
  module Admin
    class BaseController < ApplicationController
      before_action :authenticate_user!

      private

      def require_superadmin!
        return if current_user&.superadmin?
        render_error('Solo los Super Admins pueden realizar esta acción', status: :forbidden)
      end
    end
  end
end
