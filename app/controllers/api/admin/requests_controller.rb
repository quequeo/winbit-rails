module Api
  module Admin
    class RequestsController < BaseController
      def create
        permitted = params.permit(:investor_id, :request_type, :method, :amount, :network, :status, :requested_at, :processed_at)

        investor = Investor.find_by(id: permitted.fetch(:investor_id))
        return render_error('Inversor no encontrado', status: :not_found) unless investor

        requested_at = permitted[:requested_at].presence
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
          Requests::Approve.new(request_id: req.id, processed_at: processed_at).call
        elsif status_param == 'REJECTED'
          req.update!(status: 'REJECTED', processed_at: (processed_at.presence || Time.current))
        end

        render json: { data: { id: req.id } }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def update
        req = InvestorRequest.find_by(id: params[:id])
        return render_error('Solicitud no encontrada', status: :not_found) unless req

        permitted = params.permit(:investor_id, :request_type, :method, :amount, :network, :status)

        investor = Investor.find_by(id: permitted.fetch(:investor_id))
        return render_error('Inversor no encontrado', status: :not_found) unless investor

        req.update!(
          investor_id: investor.id,
          request_type: permitted.fetch(:request_type),
          method: permitted.fetch(:method),
          amount: permitted.fetch(:amount),
          network: permitted[:network].presence,
          status: permitted[:status] || req.status,
        )

        head :no_content
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def destroy
        req = InvestorRequest.find_by(id: params[:id])
        return render_error('Solicitud no encontrada', status: :not_found) unless req

        req.destroy!
        head :no_content
      end

      def approve
        req = InvestorRequest.find_by(id: params[:id])
        return render_error('Solicitud no encontrada', status: :not_found) unless req

        Requests::Approve.new(request_id: req.id, processed_at: params[:processed_at]).call

        ActivityLogger.log(
          user: current_user,
          action: 'approve_request',
          target: req,
          metadata: {
            request_type: req.request_type,
            amount: req.amount.to_f,
            method: req.method
          }
        )

        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end

      def reject
        req = InvestorRequest.find_by(id: params[:id])
        return render_error('Solicitud no encontrada', status: :not_found) unless req

        Requests::Reject.new(request_id: req.id).call

        ActivityLogger.log(
          user: current_user,
          action: 'reject_request',
          target: req,
          metadata: {
            request_type: req.request_type,
            amount: req.amount.to_f
          }
        )

        head :no_content
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end
    end
  end
end
