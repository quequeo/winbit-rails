module Api
  module Admin
    class RequestsController < BaseController
      before_action :set_request, only: [:update, :destroy, :approve, :reject]

      def create
        permitted = params.permit(:investor_id, :request_type, :method, :amount, :network, :status, :requested_at, :processed_at)

        investor = find_investor_by_id(id: permitted.fetch(:investor_id))
        return unless investor

        requested_at = permitted[:requested_at].presence || permitted[:processed_at].presence
        processed_at = permitted[:processed_at].presence
        status_param = (permitted[:status] || 'PENDING').to_s

        req = InvestorRequest.new(
          investor_id: investor.id,
          request_type: permitted.fetch(:request_type),
          method: permitted.fetch(:method),
          amount: permitted.fetch(:amount),
          network: permitted[:network].presence,
          status: 'PENDING',
          requested_at: requested_at || Time.current,
        )

        req.save!

        if status_param == 'APPROVED'
          Requests::Approve.new(request_id: req.id, processed_at: processed_at, approved_by: current_user).call
        elsif status_param == 'REJECTED'
          req.update!(status: 'REJECTED', processed_at: (processed_at.presence || Time.current))
        end

        render json: { data: { id: req.id } }, status: :created
      end

      def update
        permitted = params.permit(:investor_id, :request_type, :method, :amount, :network, :status)

        investor = find_investor_by_id(id: permitted.fetch(:investor_id))
        return unless investor
        if permitted.key?(:status) && permitted[:status].to_s != @request.status
          return render_error(
            'No se puede cambiar status desde update. Usar approve/reject.',
            status: :unprocessable_entity
          )
        end

        @request.update!(
          investor_id: investor.id,
          request_type: permitted.fetch(:request_type),
          method: permitted.fetch(:method),
          amount: permitted.fetch(:amount),
          network: permitted[:network].presence,
          status: @request.status,
        )

        head :no_content
      end

      def destroy
        if @request.status == 'APPROVED' && @request.request_type == 'WITHDRAWAL'
          Requests::ReverseApprovedWithdrawal.new(request_id: @request.id, reversed_by: current_user).call
        end

        ActivityLogger.log(
          user: current_user,
          action: 'delete_request',
          target: @request,
          metadata: {
            request_type: @request.request_type,
            amount: @request.amount.to_f,
            status: @request.status
          }
        )
        @request.destroy!
        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end

      def approve
        Requests::Approve.new(request_id: @request.id, processed_at: params[:processed_at], approved_by: current_user).call

        ActivityLogger.log(
          user: current_user,
          action: 'approve_request',
          target: @request,
          metadata: {
            request_type: @request.request_type,
            amount: @request.amount.to_f,
            method: @request.method
          }
        )

        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end

      def reject
        Requests::Reject.new(request_id: @request.id).call

        ActivityLogger.log(
          user: current_user,
          action: 'reject_request',
          target: @request,
          metadata: {
            request_type: @request.request_type,
            amount: @request.amount.to_f
          }
        )

        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end

      private

      def set_request
        @request = find_record!(
          model: InvestorRequest,
          id: params[:id],
          message: 'Solicitud no encontrada'
        )
      end
    end
  end
end
