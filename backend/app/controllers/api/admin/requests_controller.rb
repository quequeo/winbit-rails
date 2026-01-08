module Api
  module Admin
    class RequestsController < BaseController
      def approve
        Requests::Approve.new(request_id: params[:id]).call
        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end

      def reject
        Requests::Reject.new(request_id: params[:id]).call
        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end
    end
  end
end
