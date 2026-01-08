module Api
  module Public
    class RequestsController < BaseController
      def create
        payload = request.request_parameters

        email = payload['email'].to_s
        type = payload['type'].to_s
        amount = payload['amount']
        method = payload['method'].to_s
        network = payload['network']
        lemontag = payload['lemontag']
        transaction_hash = payload['transactionHash']

        unless email.match?(/\A[^@\s]+@[^@\s]+\z/)
          return render_error('Invalid request data', status: :bad_request)
        end

        investor = Investor.includes(:portfolio).find_by(email: email)
        return render_error('Investor not found', status: :not_found) unless investor
        return render_error('Investor is not active', status: :forbidden) unless investor.status_active?

        amount_num = begin
          BigDecimal(amount.to_s)
        rescue
          nil
        end

        if amount_num.nil? || amount_num <= 0
          return render_error('Invalid request data', status: :bad_request)
        end

        # Withdrawal validation: balance must be sufficient
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
          status: 'PENDING',
          requested_at: Time.current,
        )

        unless req.save
          return render_error('Invalid request data', status: :bad_request, details: req.errors.to_hash)
        end

        render json: {
          data: {
            id: req.id,
            investorId: req.investor_id,
            type: req.request_type,
            amount: req.amount.to_f,
            method: req.method,
            status: req.status,
            lemontag: req.lemontag,
            transactionHash: req.transaction_hash,
            network: req.network,
            notes: req.notes,
            requestedAt: req.requested_at,
            processedAt: req.processed_at,
          },
        }, status: :created
      end
    end
  end
end
