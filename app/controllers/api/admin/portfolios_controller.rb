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
              portfolio: inv.portfolio,
            }
          },
        }
      end

      def update
        investor = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless investor

        portfolio = Portfolio.find_by(investor_id: investor.id)

        # Get required params
        current_balance = params.require(:currentBalance).to_f
        total_invested = params.require(:totalInvested).to_f

        # Auto-calculate accumulated returns
        accumulated_return_usd = current_balance - total_invested
        accumulated_return_percent = total_invested > 0 ? (accumulated_return_usd / total_invested) * 100 : 0

        # Annual returns can still be provided manually or calculated
        annual_return_usd = params[:annualReturnUSD]&.to_f || 0
        annual_return_percent = params[:annualReturnPercent]&.to_f || 0

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

        # Log activity
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
