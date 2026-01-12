module Api
  module Admin
    class RequestsController < BaseController
      def create
        investor = Investor.find_by(id: params.require(:investor_id))
        return render_error('Inversor no encontrado', status: :not_found) unless investor

        req = InvestorRequest.new(
          investor_id: investor.id,
          request_type: params.require(:request_type),
          method: params.require(:method),
          amount: params.require(:amount),
          network: params[:network].presence,
          status: params[:status] || 'PENDING',
          requested_at: Time.current,
        )

        req.save!
        render json: { data: { id: req.id } }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def update
        req = InvestorRequest.find_by(id: params[:id])
        return render_error('Solicitud no encontrada', status: :not_found) unless req

        investor = Investor.find_by(id: params.require(:investor_id))
        return render_error('Inversor no encontrado', status: :not_found) unless investor

        req.update!(
          investor_id: investor.id,
          request_type: params.require(:request_type),
          method: params.require(:method),
          amount: params.require(:amount),
          network: params[:network].presence,
          status: params[:status] || req.status,
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
        req = InvestorRequest.find(params[:id])
        Requests::Approve.new(request_id: params[:id]).call

        # Log activity
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
        req = InvestorRequest.find(params[:id])
        Requests::Reject.new(request_id: params[:id]).call

        # Log activity
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
