module Api
  module Public
    class BaseController < ApplicationController
      private

      def render_error(message, status: :bad_request, details: nil)
        payload = { error: message }
        payload[:details] = details if details
        render json: payload, status: status
      end
    end
  end
end
