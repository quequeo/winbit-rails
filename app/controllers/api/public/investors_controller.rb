module Api
  module Public
    class InvestorsController < BaseController
      def show
        email = CGI.unescape(params[:email].to_s)

        investor = Investor.includes(:portfolio).find_by(email: email)
        return render_error('Investor not found', status: :not_found) unless investor
        return render_error('Investor is not active', status: :forbidden) unless investor.status_active?

        response = {
          investor: {
            email: investor.email,
            name: format_name(investor.name),
          },
          portfolio: investor.portfolio ? {
            currentBalance: investor.portfolio.current_balance.to_f,
            totalInvested: investor.portfolio.total_invested.to_f,
            accumulatedReturnUSD: investor.portfolio.accumulated_return_usd.to_f,
            accumulatedReturnPercent: investor.portfolio.accumulated_return_percent.to_f,
            annualReturnUSD: investor.portfolio.annual_return_usd.to_f,
            annualReturnPercent: investor.portfolio.annual_return_percent.to_f,
            updatedAt: investor.portfolio.updated_at,
          } : nil,
        }

        render json: { data: response }
      end

      def history
        email = CGI.unescape(params[:email].to_s)

        investor = Investor.find_by(email: email)
        return render_error('Investor not found', status: :not_found) unless investor
        return render_error('Investor is not active', status: :forbidden) unless investor.status_active?

        # Portfolio histories (completed movements)
        histories = investor.portfolio_histories.order(date: :desc).map { |h|
          {
            id: h.id,
            investorId: h.investor_id,
            date: h.date,
            event: h.event,
            amount: h.amount.to_f,
            previousBalance: h.previous_balance.to_f,
            newBalance: h.new_balance.to_f,
            status: h.status,
            createdAt: h.created_at,
          }
        }

        # Pending and rejected requests
        requests = investor.investor_requests.where(status: ['PENDING', 'REJECTED']).order(requested_at: :desc).map { |r|
          {
            id: "request_#{r.id}",
            investorId: r.investor_id,
            date: r.requested_at,
            event: r.request_type,
            amount: r.amount.to_f,
            previousBalance: nil,
            newBalance: nil,
            status: r.status,
            createdAt: r.requested_at,
            method: r.method,
            network: r.network,
            rejectionReason: r.rejection_reason,
          }
        }

        # Combine and sort by date
        combined = (histories + requests).sort_by { |item| item[:date] }.reverse

        render json: { data: combined }
      end

      private

      def format_name(name)
        name.to_s
          .downcase
          .split(' ')
          .map { |w| w[0] ? w[0].upcase + w[1..] : w }
          .join(' ')
      end
    end
  end
end
