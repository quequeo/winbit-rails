module Api
  module Admin
    class PortfoliosController < BaseController
      before_action :require_superadmin!, only: [:update]

      def index
        investors = Investor.includes(:portfolio).where(status: 'ACTIVE').order(created_at: :desc)

        render json: {
          data: investors.map { |inv|
            {
              id: inv.id,
              email: inv.email,
              name: inv.name,
              portfolio: inv.portfolio,
            }
          },
        }
      end

      def update
        investor = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless investor

        permitted = params.permit(:currentBalance, :totalInvested, :annualReturnUSD, :annualReturnPercent)

        portfolio = Portfolio.find_by(investor_id: investor.id)

        current_balance = permitted.fetch(:currentBalance).to_f
        total_invested = permitted.fetch(:totalInvested).to_f

        accumulated_return_usd = current_balance - total_invested
        accumulated_return_percent = total_invested > 0 ? (accumulated_return_usd / total_invested) * 100 : 0

        annual_return_usd = permitted[:annualReturnUSD]&.to_f || 0
        annual_return_percent = permitted[:annualReturnPercent]&.to_f || 0

        attrs = {
          current_balance: current_balance,
          total_invested: total_invested,
          accumulated_return_usd: accumulated_return_usd,
          accumulated_return_percent: accumulated_return_percent,
          annual_return_usd: annual_return_usd,
          annual_return_percent: annual_return_percent,
        }

        if portfolio
          portfolio.update!(attrs)
        else
          portfolio = Portfolio.create!(attrs.merge(investor_id: investor.id))
        end

        ActivityLogger.log(
          user: current_user,
          action: 'update_portfolio',
          target: portfolio,
          metadata: {
            current_balance: current_balance,
            accumulated_return_usd: accumulated_return_usd,
          }
        )

        head :no_content
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end
    end
  end
end
