module Api
  module Admin
    class InvestorsController < BaseController
      before_action :require_superadmin!, only: [:destroy]
      before_action :set_investor, only: [:update, :toggle_status, :destroy]
      before_action :set_investor_with_associations, only: [:show]
      before_action :set_investor_with_portfolio, only: [:referral_commissions]

      def index
        sort_by = params[:sort_by] || 'created_at'
        sort_order = %w[asc desc].include?(params[:sort_order]) ? params[:sort_order] : 'desc'

        investors = Investor.includes(:portfolio)

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
          data: investors.map { |inv| AdminInvestorSerializer.new(inv).as_json }
        }
      end

      def show
        render json: {
          data: AdminInvestorDetailSerializer.new(@investor).as_json
        }
      end

      def create
        inv = Investor.new(investor_create_params)

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
        @investor.update!(investor_update_params)

        ActivityLogger.log(
          user: current_user,
          action: 'update_investor',
          target: @investor
        )

        head :no_content
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def toggle_status
        old_status = @investor.status
        new_status = @investor.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'
        @investor.update!(status: new_status)

        action = new_status == 'ACTIVE' ? 'activate_investor' : 'deactivate_investor'
        ActivityLogger.log(
          user: current_user,
          action: action,
          target: @investor,
          metadata: { from: old_status, to: new_status }
        )

        head :no_content
      end

      # POST /api/admin/investors/:id/referral_commissions
      def referral_commissions
        permitted = params.permit(:amount, :applied_at)
        amount = permitted.fetch(:amount)
        applied_at = permitted[:applied_at].presence

        portfolio = @investor.portfolio || Portfolio.create!(investor: @investor)
        from_balance = portfolio.current_balance.to_f

        applicator = ReferralCommissionApplicator.new(
          @investor,
          amount: amount,
          applied_by: current_user,
          applied_at: applied_at
        )

        if applicator.apply
          portfolio.reload

          ActivityLogger.log(
            user: current_user,
            action: 'apply_referral_commission',
            target: @investor,
            metadata: {
              amount: amount.to_f,
              from: from_balance,
              to: portfolio.current_balance.to_f
            }
          )

          render json: {
            data: {
              investor_id: @investor.id,
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
        ActivityLogger.log(
          user: current_user,
          action: 'delete_investor',
          target: @investor
        )

        @investor.destroy!
        head :no_content
      end

      private

      def set_investor
        @investor = find_investor_by_id(id: params[:id])
      end

      def set_investor_with_associations
        @investor = find_investor_by_id(
          id: params[:id],
          includes: [:portfolio, :portfolio_histories, :investor_requests]
        )
      end

      def set_investor_with_portfolio
        @investor = find_investor_by_id(id: params[:id], includes: [:portfolio])
      end

      def investor_create_params
        permitted = params.permit(:email, :name, :trading_fee_frequency, :password)
        attrs = {
          email: permitted.fetch(:email),
          name: permitted.fetch(:name),
          status: 'ACTIVE',
          trading_fee_frequency: permitted[:trading_fee_frequency].presence || 'QUARTERLY',
        }
        attrs[:password] = permitted[:password] if permitted[:password].present?
        attrs
      end

      def investor_update_params
        permitted = params.permit(:email, :name, :status, :trading_fee_frequency, :password)
        attrs = {
          email: permitted.fetch(:email),
          name: permitted.fetch(:name),
        }
        attrs[:status] = permitted[:status] if permitted.key?(:status)
        attrs[:trading_fee_frequency] = permitted[:trading_fee_frequency] if permitted.key?(:trading_fee_frequency)
        attrs[:password] = permitted[:password] if permitted[:password].present?
        attrs
      end
    end
  end
end
