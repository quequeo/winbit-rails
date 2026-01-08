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
            code: investor.code,
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

        history = investor.portfolio_histories.order(date: :desc)

        render json: {
          data: history.map { |h|
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
          },
        }
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
