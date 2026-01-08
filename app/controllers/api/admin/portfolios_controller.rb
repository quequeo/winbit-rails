module Api
  module Admin
    class PortfoliosController < BaseController
      def index
        investors = Investor.includes(:portfolio).where(status: 'ACTIVE').order(created_at: :desc)

        render json: {
          data: investors.map { |inv|
            {
              id: inv.id,
              email: inv.email,
              name: inv.name,
              code: inv.code,
              portfolio: inv.portfolio,
            }
          },
        }
      end

      def update
        investor = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless investor

        portfolio = Portfolio.find_by(investor_id: investor.id)
        attrs = {
          current_balance: params.require(:currentBalance),
          total_invested: params.require(:totalInvested),
          accumulated_return_usd: params.require(:accumulatedReturnUSD),
          accumulated_return_percent: params.require(:accumulatedReturnPercent),
          annual_return_usd: params.require(:annualReturnUSD),
          annual_return_percent: params.require(:annualReturnPercent),
        }

        if portfolio
          portfolio.update!(attrs)
        else
          Portfolio.create!(attrs.merge(investor_id: investor.id))
        end

        head :no_content
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end
    end
  end
end
