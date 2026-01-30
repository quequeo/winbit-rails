module Api
  module Admin
    class InvestorsController < BaseController
      def index
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'

        # Validar sort_order
        sort_order = %w[asc desc].include?(sort_order) ? sort_order : 'desc'

        investors = Investor.includes(:portfolio)

        # Aplicar ordenamiento
        case sort_by
        when 'balance'
          investors = investors.left_joins(:portfolio)
                               .order(Arel.sql("COALESCE(portfolios.current_balance, 0) #{sort_order}"))
        when 'status'
          investors = investors.order(status: sort_order, created_at: :desc)
        when 'name'
          investors = investors.order(name: sort_order)
        else
          investors = investors.order(created_at: :desc)
        end

        render json: {
          data: investors.map { |inv|
            {
              id: inv.id,
              email: inv.email,
              name: inv.name,
              status: inv.status,
              tradingFeeFrequency: inv.trading_fee_frequency,
              createdAt: inv.created_at,
              updatedAt: inv.updated_at,
              portfolio: inv.portfolio ? {
                currentBalance: inv.portfolio.current_balance.to_f,
              } : nil,
            }
          },
        }
      end

      def show
        inv = Investor.includes(:portfolio, :portfolio_histories, :investor_requests).find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        render json: {
          data: {
            id: inv.id,
            email: inv.email,
            name: inv.name,
            status: inv.status,
            portfolio: inv.portfolio,
            portfolioHistory: inv.portfolio_histories.order(date: :desc).limit(10),
            requests: inv.investor_requests.order(requested_at: :desc).limit(10),
          },
        }
      end

      def create
        inv = Investor.new(
          email: params.require(:email),
          name: params.require(:name),
          status: 'ACTIVE',
          trading_fee_frequency: params[:trading_fee_frequency].presence || 'QUARTERLY',
        )

        ActiveRecord::Base.transaction do
          inv.save!
          Portfolio.create!(
            investor_id: inv.id,
            current_balance: 0,
            total_invested: 0,
            accumulated_return_usd: 0,
            accumulated_return_percent: 0,
            annual_return_usd: 0,
            annual_return_percent: 0,
          )

          # Log activity
          ActivityLogger.log(
            user: current_user,
            action: 'create_investor',
            target: inv
          )
        end

        render json: { data: { id: inv.id } }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def update
        inv = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        attrs = {
          email: params.require(:email),
          name: params.require(:name),
        }
        if params.key?(:trading_fee_frequency)
          attrs[:trading_fee_frequency] = params[:trading_fee_frequency]
        end

        inv.update!(attrs)

        # Log activity
        ActivityLogger.log(
          user: current_user,
          action: 'update_investor',
          target: inv
        )

        head :no_content
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def toggle_status
        inv = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        old_status = inv.status
        new_status = inv.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'
        inv.update!(status: new_status)

        # Log activity
        action = new_status == 'ACTIVE' ? 'activate_investor' : 'deactivate_investor'
        ActivityLogger.log(
          user: current_user,
          action: action,
          target: inv,
          metadata: { from: old_status, to: new_status }
        )

        head :no_content
      end

      # POST /api/admin/investors/:id/referral_commissions
      # Body: { amount: number, applied_at?: string }
      def referral_commissions
        inv = Investor.includes(:portfolio).find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        amount = params.require(:amount)
        applied_at = params[:applied_at].presence

        portfolio = inv.portfolio || Portfolio.create!(investor: inv)
        from_balance = portfolio.current_balance.to_f

        applicator = ReferralCommissionApplicator.new(
          inv,
          amount: amount,
          applied_by: current_user,
          applied_at: applied_at
        )

        if applicator.apply
          portfolio.reload

          ActivityLogger.log(
            user: current_user,
            action: 'apply_referral_commission',
            target: inv,
            metadata: {
              amount: amount.to_f,
              from: from_balance,
              to: portfolio.current_balance.to_f
            }
          )

          render json: {
            data: {
              investor_id: inv.id,
              current_balance: portfolio.current_balance.to_f
            }
          }, status: :created
        else
          render_error(applicator.errors.join(', '), status: :unprocessable_entity)
        end
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end

      def destroy
        inv = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        # Log activity before destroying
        ActivityLogger.log(
          user: current_user,
          action: 'delete_investor',
          target: inv
        )

        inv.destroy!
        head :no_content
      end
    end
  end
end
