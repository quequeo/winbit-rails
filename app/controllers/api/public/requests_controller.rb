module Api
  module Public
    class RequestsController < BaseController
      def create
        # Support both wrapped (params['request']) and unwrapped params
        raw = params['request'] || params
        payload = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h

        email = payload['email'].to_s.strip
        type = payload['type'].to_s
        amount = payload['amount']
        method = payload['method'].to_s
        network = payload['network']
        lemontag = payload['lemontag']
        transaction_hash = payload['transactionHash']
        attachment_url = payload['attachmentUrl']

        if email.blank?
          return render_error('Email is required', status: :bad_request)
        end
        unless email.match?(/\A[^@\s]+@[^@\s]+\z/)
          return render_error('Invalid email format', status: :bad_request)
        end

        investor = find_investor_by_email(email: email, includes: [:portfolio], message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        amount_num = begin
          BigDecimal(amount.to_s)
        rescue
          nil
        end

        if amount_num.nil? || amount_num <= 0
          return render_error('Invalid request data', status: :bad_request)
        end

        cash_methods = %w[CASH_ARS CASH_USD]
        if type == 'DEPOSIT' && !cash_methods.include?(method) && attachment_url.blank?
          return render_error('Attachment is required for non-cash deposits', status: :bad_request)
        end

        if type == 'WITHDRAWAL'
          if investor.portfolio.nil?
            return render_error('No portfolio found', status: :bad_request)
          end
          if BigDecimal(investor.portfolio.current_balance.to_s) < amount_num
            return render_error('Insufficient balance', status: :bad_request)
          end
        end

        req = InvestorRequest.new(
          investor_id: investor.id,
          request_type: type,
          amount: amount_num,
          method: method,
          network: network,
          lemontag: lemontag,
          transaction_hash: transaction_hash,
          attachment_url: attachment_url,
          status: 'PENDING',
          requested_at: Time.current,
        )

        unless req.save
          return render_error('Invalid request data', status: :bad_request, details: req.errors.to_hash)
        end

        begin
          if req.request_type == 'DEPOSIT'
            InvestorMailer.deposit_created(investor, req).deliver_later
            AdminMailer.new_deposit_notification(req).deliver_later
          elsif req.request_type == 'WITHDRAWAL'
            InvestorMailer.withdrawal_created(investor, req).deliver_later
            AdminMailer.new_withdrawal_notification(req).deliver_later
          end
        rescue => e
          Rails.logger.error("Failed to send email notification: #{e.message}")
        end

        render json: {
          data: PublicRequestSerializer.new(req).as_json
        }, status: :created
      end
    end
  end
end
