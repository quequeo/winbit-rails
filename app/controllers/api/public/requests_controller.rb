module Api
  module Public
    class RequestsController < BaseController
      def create
        payload = request_params

        email = payload[:email].to_s.strip
        request_type = payload[:type].to_s
        amount = payload[:amount]
        method = payload[:method].to_s
        network = payload[:network]
        wallet_address = payload[:walletAddress]
        lemontag = payload[:lemontag]
        transaction_hash = payload[:transactionHash]
        attachment_url = payload[:attachmentUrl]
        asset = payload[:asset].presence
        replaces_request_id = payload[:replacesRequestId].presence

        if email.blank?
          return render_error('Email is required', status: :bad_request)
        end
        unless email.match?(/\A[^@\s]+@[^@\s]+\z/)
          return render_error('Invalid email format', status: :bad_request)
        end

        investor = find_investor_by_email(email: email, includes: [:portfolio], message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        amount_num = BigDecimal(amount.to_s)
        if amount_num.nil? || amount_num <= 0
          return render_error('Invalid request data', status: :bad_request)
        end

        if InvestorRequest::ARS_METHODS.include?(method)
          return render_error('Por el momento no se aceptan operaciones en pesos', status: :bad_request)
        end

        cash_methods = %w[CASH_ARS CASH_USD]
        if request_type == 'DEPOSIT' && !cash_methods.include?(method) && attachment_url.blank?
          return render_error('Attachment is required for non-cash deposits', status: :bad_request)
        end

        if request_type == 'WITHDRAWAL'
          if investor.portfolio.nil?
            return render_error('No portfolio found', status: :bad_request)
          end
          if BigDecimal(investor.portfolio.current_balance.to_s) < amount_num
            return render_error('Insufficient balance', status: :bad_request)
          end
        end

        req = InvestorRequest.new(
          investor_id: investor.id,
          request_type: request_type,
          amount: amount_num,
          method: method,
          network: network,
          asset: asset,
          wallet_address: wallet_address,
          lemontag: lemontag,
          transaction_hash: transaction_hash,
          attachment_url: attachment_url,
          status: 'PENDING',
          requested_at: Time.current,
        )

        replaced_request = nil
        outcome = InvestorRequest.transaction do
          # Corrección: la nueva solicitud reemplaza a una pendiente del mismo inversor.
          if replaces_request_id
            replaced_request = investor.investor_requests.lock.find_by(id: replaces_request_id)
            next :replaced_not_found unless replaced_request
            next :replaced_not_pending unless replaced_request.status == 'PENDING'
            next :replaced_other_type unless replaced_request.request_type == request_type
          end

          next :invalid unless req.save

          replaced_request&.cancel_by_investor!
          :created
        end

        case outcome
        when :replaced_not_found
          return render_error('Request not found', status: :not_found)
        when :replaced_not_pending
          return render_error('La solicitud original ya fue procesada y no se puede corregir', status: :unprocessable_content)
        when :replaced_other_type
          return render_error('La corrección tiene que ser del mismo tipo que la solicitud original', status: :unprocessable_content)
        when :invalid
          return render_error('Invalid request data', status: :bad_request, details: req.errors.to_hash)
        end

        Requests::NotifyCreated.call(request: req, replaced_request: replaced_request)

        render json: {
          data: PublicRequestSerializer.new(req).as_json
        }, status: :created
      rescue ArgumentError, TypeError
        render_error('Invalid request data', status: :bad_request)
      end

      def cancel
        email = cancel_params[:email].to_s.strip
        investor = Investor.find_by(email: email) if email.present?
        req = investor&.investor_requests&.find_by(id: params[:id])
        return render_error('Request not found', status: :not_found) unless req

        req.cancel_by_investor!

        begin
          AdminMailer.request_cancelled_notification(req).deliver_now
        rescue => e
          Rails.logger.error("Failed to send email notification: #{e.message}")
        end

        render json: { data: PublicRequestSerializer.new(req).as_json }
      rescue InvestorRequest::NotCancellable
        render_error('La solicitud ya fue procesada y no se puede cancelar', status: :unprocessable_content)
      end

      private

      def cancel_params
        params[:request].present? ? params.require(:request).permit(:email) : params.permit(:email)
      end

      def request_params
        if params[:request].present?
          params.require(:request).permit(
            :email, :type, :amount, :method, :network, :lemontag, :transactionHash, :attachmentUrl, :walletAddress, :asset,
            :replacesRequestId
          )
        else
          params.permit(
            :email, :type, :amount, :method, :network, :lemontag, :transactionHash, :attachmentUrl, :walletAddress, :asset,
            :replacesRequestId
          )
        end
      end
    end
  end
end
