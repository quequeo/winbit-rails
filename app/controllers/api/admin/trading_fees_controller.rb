module Api
  module Admin
    class TradingFeesController < BaseController
      before_action :set_investor, only: [:calculate, :create]
      before_action :set_trading_fee, only: [:update, :destroy]

      def index
        include_voided = ActiveModel::Type::Boolean.new.cast(params[:include_voided])

        fees = TradingFee.joins(:investor)
                         .where(investors: { status: 'ACTIVE' })
                         .includes(:investor, :applied_by)
                         .order(applied_at: :desc)
        fees = fees.active unless include_voided

        fees = fees.where(investor_id: params[:investor_id]) if params[:investor_id].present?

        if params[:period_start].present? && params[:period_end].present?
          fees = fees.where('period_start >= ? AND period_end <= ?', params[:period_start], params[:period_end])
        end

        fees = fees.select { |fee| fee_backed_by_history?(fee) }
        paginated = paginate_array(fees, default_per_page: 25, max_per_page: 25)

        render json: {
          data: paginated[:records].map { |fee| TradingFeeSerializer.new(fee).as_json },
          pagination: paginated[:pagination]
        }
      end

      def calculate
        start_date, end_date = extract_period_params

        if start_date && end_date
          ok = validate_period_for_investor!(@investor, start_date, end_date)
          return unless ok

          profit_amount = profits_for(@investor, start_date, end_date)
          existing_fee = TradingFee.active.find_by(investor_id: @investor.id, period_start: start_date, period_end: end_date)

          if existing_fee
            render json: {
              error: 'Trading fee ya aplicado para este período',
              period_start: start_date,
              period_end: end_date,
              profit_amount: profit_amount,
              fee_percentage: existing_fee.fee_percentage,
              fee_amount: existing_fee.fee_amount,
              already_applied: true
            }, status: :conflict
            return
          end

          if profit_amount <= 0
            render json: {
              error: 'No hay ganancias en el período',
              period_start: start_date,
              period_end: end_date,
              profit_amount: 0
            }, status: :unprocessable_entity
            return
          end

          fee_percentage = params[:fee_percentage].present? ? params[:fee_percentage].to_f : @investor.trading_fee_percentage.to_f
          fee_amount = (profit_amount * (fee_percentage / 100.0)).round(2)

          render json: {
            investor_id: @investor.id,
            investor_name: @investor.name,
            period_start: start_date,
            period_end: end_date,
            profit_amount: profit_amount,
            fee_percentage: fee_percentage,
            fee_amount: fee_amount,
            current_balance: @investor.portfolio.current_balance,
            balance_after_fee: @investor.portfolio.current_balance - fee_amount,
            already_applied: false
          }
          return
        end

        calculator = TradingFeeCalculator.new(@investor)
        result = calculator.calculate

        existing_fee = TradingFee.active.find_by(
          investor_id: @investor.id,
          period_start: result[:period_start],
          period_end: result[:period_end]
        )

        if existing_fee
          render json: {
            error: 'Trading fee ya aplicado para este período',
            period_start: result[:period_start],
            period_end: result[:period_end],
            profit_amount: result[:profit_amount],
            fee_percentage: existing_fee.fee_percentage,
            fee_amount: existing_fee.fee_amount,
            already_applied: true
          }, status: :conflict
          return
        end

        if result[:profit_amount] <= 0
          render json: {
            error: 'No hay ganancias en el período',
            period_start: result[:period_start],
            period_end: result[:period_end],
            profit_amount: 0
          }, status: :unprocessable_entity
          return
        end

        fee_percentage = params[:fee_percentage].present? ? params[:fee_percentage].to_f : @investor.trading_fee_percentage.to_f
        fee_amount = (result[:profit_amount] * (fee_percentage / 100.0)).round(2)

        render json: {
          investor_id: @investor.id,
          investor_name: @investor.name,
          period_start: result[:period_start],
          period_end: result[:period_end],
          profit_amount: result[:profit_amount],
          fee_percentage: fee_percentage,
          fee_amount: fee_amount,
          current_balance: @investor.portfolio.current_balance,
          balance_after_fee: @investor.portfolio.current_balance - fee_amount,
          already_applied: false
        }
      end

      def create
        fee_percentage = params[:fee_percentage].present? ? params[:fee_percentage].to_f : @investor.trading_fee_percentage.to_f

        if fee_percentage <= 0 || fee_percentage > 100
          render_error('El porcentaje debe estar entre 0 y 100', status: :unprocessable_entity)
          return
        end

        start_date, end_date = extract_period_params

        if start_date && end_date
          ok = validate_period_for_investor!(@investor, start_date, end_date)
          return unless ok

          if TradingFee.active.exists?(investor_id: @investor.id, period_start: start_date, period_end: end_date)
            render_error('Trading fee ya aplicado para este período', status: :conflict)
            return
          end

          applicator = TradingFeeApplicator.new(
            @investor,
            fee_percentage: fee_percentage,
            applied_by: current_user,
            notes: params[:notes],
            period_start: start_date,
            period_end: end_date
          )

          if applicator.apply
            fee = TradingFee.where(investor_id: @investor.id, period_start: start_date, period_end: end_date).order(applied_at: :desc).first

            ActivityLogger.log(
              user: current_user,
              target: fee,
              action: 'apply_trading_fee',
              metadata: {
                amount: applicator.fee_amount,
                request_type: 'TRADING_FEE',
                from: @investor.portfolio&.current_balance.to_f,
                to: (@investor.portfolio&.current_balance.to_f - applicator.fee_amount.to_f)
              }
            )

            render json: TradingFeeSerializer.new(fee).as_json, status: :created
          else
            render_error(applicator.errors.join(', '), status: :unprocessable_entity)
          end
          return
        end

        result = TradingFeeCalculator.new(@investor).calculate
        if TradingFee.active.exists?(investor_id: @investor.id, period_start: result[:period_start], period_end: result[:period_end])
          render_error('Trading fee ya aplicado para este período', status: :conflict)
          return
        end

        applicator = TradingFeeApplicator.new(
          @investor,
          fee_percentage: fee_percentage,
          applied_by: current_user,
          notes: params[:notes]
        )

        if applicator.apply
          fee = TradingFee.where(investor_id: @investor.id).order(applied_at: :desc).first

          ActivityLogger.log(
            user: current_user,
            target: fee,
            action: 'apply_trading_fee',
            metadata: {
              amount: applicator.fee_amount,
              request_type: 'TRADING_FEE',
              from: @investor.portfolio&.current_balance.to_f,
              to: (@investor.portfolio&.current_balance.to_f - applicator.fee_amount.to_f)
            }
          )

          render json: TradingFeeSerializer.new(fee).as_json, status: :created
        else
          render_error(applicator.errors.join(', '), status: :unprocessable_entity)
        end
      end

      def update
        return unless @trading_fee

        fee_percentage = params[:fee_percentage]&.to_f
        notes = params[:notes]

        if fee_percentage.blank? || fee_percentage <= 0 || fee_percentage > 100
          render_error('El porcentaje debe estar entre 0 y 100', status: :unprocessable_entity)
          return
        end

        fee = @trading_fee
        investor = fee.investor
        portfolio = investor.portfolio
        unless portfolio
          render_error('Portfolio no encontrado', status: :unprocessable_entity)
          return
        end

        old_fee_amount = fee.fee_amount.to_f
        new_fee_amount = (fee.profit_amount.to_f * (fee_percentage / 100.0)).round(2)
        delta = (new_fee_amount - old_fee_amount).round(2)

        ApplicationRecord.transaction do
          old_fee_percentage = fee.fee_percentage.to_f

          fee.update!(
            fee_percentage: fee_percentage,
            fee_amount: new_fee_amount,
            notes: notes
          )

          if delta != 0.0
            new_balance = (portfolio.current_balance.to_f - delta).round(2)
            if new_balance < 0
              fee.errors.add(:base, 'Insufficient balance to apply trading fee adjustment')
              raise ActiveRecord::RecordInvalid, fee
            end

            PortfolioHistory.create!(
              investor: investor,
              event: 'TRADING_FEE_ADJUSTMENT',
              amount: (-delta).round(2),
              previous_balance: portfolio.current_balance.to_f,
              new_balance: new_balance,
              status: 'COMPLETED',
              date: Time.current
            )

            portfolio.update!(current_balance: new_balance)
          end

          ActivityLogger.log(
            user: current_user,
            target: fee,
            action: 'update_trading_fee',
            metadata: {
              amount: new_fee_amount,
              from: old_fee_amount,
              to: new_fee_amount
            }
          )
        end

        render json: TradingFeeSerializer.new(fee.reload).as_json, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message, status: :unprocessable_entity)
      rescue StandardError => e
        render_error("Error updating trading fee: #{e.message}", status: :unprocessable_entity)
      end

      def destroy
        return unless @trading_fee

        fee = @trading_fee
        if fee.voided_at.present?
          render_error('Trading fee ya fue anulada', status: :conflict)
          return
        end

        investor = fee.investor
        portfolio = investor.portfolio
        unless portfolio
          render_error('Portfolio no encontrado', status: :unprocessable_entity)
          return
        end

        fee_amount = fee.fee_amount.to_f

        ApplicationRecord.transaction do
          new_balance = (portfolio.current_balance.to_f + fee_amount).round(2)

          PortfolioHistory.create!(
            investor: investor,
            event: 'TRADING_FEE_ADJUSTMENT',
            amount: fee_amount.round(2),
            previous_balance: portfolio.current_balance.to_f,
            new_balance: new_balance,
            status: 'COMPLETED',
            date: Time.current
          )

          portfolio.update!(current_balance: new_balance)

          fee.update!(voided_at: Time.current, voided_by: current_user)

          ActivityLogger.log(
            user: current_user,
            target: fee,
            action: 'void_trading_fee',
            metadata: {
              amount: fee_amount,
              from: fee_amount,
              to: 0
            }
          )
        end

        render json: TradingFeeSerializer.new(fee.reload).as_json, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message, status: :unprocessable_entity)
      rescue StandardError => e
        render_error("Error voiding trading fee: #{e.message}", status: :unprocessable_entity)
      end

      def investors_summary
        investors = Investor.where(status: 'ACTIVE').includes(:portfolio)

        start_date, end_date = extract_period_params

        summary = investors.map do |investor|
          if start_date && end_date
            invested = invested_amount_at(investor, end_date)
            next if invested <= 0

            profit_amount = profits_for(investor, start_date, end_date)
            existing_fee = TradingFee.active.find_by(investor_id: investor.id, period_start: start_date, period_end: end_date)
            existing_fee = nil if existing_fee.present? && !fee_backed_by_history?(existing_fee)

            TradingFeeInvestorSummarySerializer.new(
              investor: investor,
              period_start: start_date,
              period_end: end_date,
              profit_amount: profit_amount,
              monthly_profits: monthly_breakdown_for(investor, start_date, end_date),
              existing_fee: existing_fee
            ).as_json
          else
            calculator = TradingFeeCalculator.new(investor)
            result = calculator.calculate

            invested = invested_amount_at(investor, result[:period_end])
            next if invested <= 0

            existing_fee = TradingFee.active.find_by(
              investor_id: investor.id,
              period_start: result[:period_start],
              period_end: result[:period_end]
            )
            existing_fee = nil if existing_fee.present? && !fee_backed_by_history?(existing_fee)

            TradingFeeInvestorSummarySerializer.new(
              investor: investor,
              period_start: result[:period_start],
              period_end: result[:period_end],
              profit_amount: result[:profit_amount],
              monthly_profits: monthly_breakdown_for(investor, result[:period_start], result[:period_end]),
              existing_fee: existing_fee
            ).as_json
          end
        end

        summary = summary.compact

        render json: summary
      end

      private

      def set_investor
        investor_id = params[:investor_id] || params[:id]
        @investor = find_investor_by_id(id: investor_id, includes: [:portfolio])
      end

      def set_trading_fee
        @trading_fee = find_record!(
          model: TradingFee,
          id: params[:id],
          includes: [:investor],
          message: 'Trading fee no encontrado'
        )
      end

      def extract_period_params
        return [nil, nil] unless params[:period_start].present? && params[:period_end].present?

        start_date = parse_date_param(params[:period_start])
        end_date = parse_date_param(params[:period_end])
        return [nil, nil] if start_date.blank? || end_date.blank?

        [start_date, end_date]
      end

      def validate_period_for_investor!(investor, start_date, end_date)
        return true if investor.blank? || start_date.blank? || end_date.blank?
        return true unless investor.respond_to?(:trading_fee_frequency)

        case investor.trading_fee_frequency
        when 'MONTHLY'
          expected_start = start_date.beginning_of_month.to_date
          expected_end = start_date.end_of_month.to_date
          if start_date != expected_start || end_date != expected_end
            render_error('Este inversor está configurado como MONTHLY: el período debe ser un mes calendario completo', status: :unprocessable_entity)
            return false
          end
        when 'QUARTERLY'
          expected_start = start_date.beginning_of_quarter.to_date
          expected_end = start_date.end_of_quarter.to_date
          if start_date != expected_start || end_date != expected_end
            render_error('Este inversor está configurado como QUARTERLY: el período debe ser un trimestre completo', status: :unprocessable_entity)
            return false
          end
        when 'SEMESTRAL'
          valid_semesters = [
            [Date.new(start_date.year, 1, 1), Date.new(start_date.year, 6, 30)],
            [Date.new(start_date.year, 7, 1), Date.new(start_date.year, 12, 31)]
          ]
          unless valid_semesters.any? { |s, e| start_date == s && end_date == e }
            render_error('Este inversor está configurado como SEMESTRAL: el período debe ser un semestre completo (Ene-Jun o Jul-Dic)', status: :unprocessable_entity)
            return false
          end
        when 'ANNUAL'
          expected_start = start_date.beginning_of_year.to_date
          expected_end = start_date.end_of_year.to_date
          if start_date != expected_start || end_date != expected_end
            render_error('Este inversor está configurado como ANNUAL: el período debe ser un año calendario completo', status: :unprocessable_entity)
            return false
          end
        end

        true
      end

      def monthly_breakdown_for(investor, start_date, end_date)
        return [] if start_date.blank? || end_date.blank?

        start_date = start_date.to_date
        end_date = end_date.to_date
        range = start_date.beginning_of_day..end_date.end_of_day

        grouped = PortfolioHistory.where(investor_id: investor.id)
                                 .where(event: 'OPERATING_RESULT', status: 'COMPLETED')
                                 .where(date: range)
                                 .group("DATE_TRUNC('month', date)")
                                 .sum(:amount)

        months_between(start_date, end_date).map do |m|
          key = Time.utc(m.year, m.month, 1)
          amount = grouped[key]&.to_f || 0.0
          { month: m.strftime('%Y-%m'), amount: amount }
        end
      end

      def months_between(start_date, end_date)
        return [] if start_date.blank? || end_date.blank?

        start_m = start_date.to_date.beginning_of_month
        end_m = end_date.to_date.beginning_of_month
        months = []
        cur = start_m
        while cur <= end_m
          months << cur
          cur = (cur >> 1)
        end
        months
      end

      def invested_amount_at(investor, at_date)
        return 0.0 if at_date.blank?

        range = ..at_date.to_date.end_of_day

        deposits = PortfolioHistory.where(investor_id: investor.id)
                                  .where(event: 'DEPOSIT', status: 'COMPLETED')
                                  .where(date: range)
                                  .sum(:amount)
                                  .to_f

        withdrawals = PortfolioHistory.where(investor_id: investor.id)
                                     .where(event: 'WITHDRAWAL', status: 'COMPLETED')
                                     .where(date: range)
                                     .sum(:amount)
                                     .to_f

        (deposits - withdrawals).round(2)
      end

      def profits_for(investor, start_date, end_date)
        range = start_date.to_date.beginning_of_day..end_date.to_date.end_of_day

        PortfolioHistory.where(investor_id: investor.id)
                       .where(event: 'OPERATING_RESULT', status: 'COMPLETED')
                       .where(date: range)
                       .sum(:amount)
                       .to_f
      end

      # Protects admin views against stale fee rows when old movements were deleted manually.
      def fee_backed_by_history?(fee)
        return false if fee.blank?

        min_time = fee.applied_at - 5.minutes
        max_time = fee.applied_at + 5.minutes
        expected_amount = -fee.fee_amount.to_f

        PortfolioHistory.where(investor_id: fee.investor_id, event: 'TRADING_FEE', status: 'COMPLETED')
                        .where(date: min_time..max_time)
                        .where(amount: expected_amount)
                        .exists?
      end

      def paginate_array(records, default_per_page:, max_per_page:)
        page = params[:page].to_i
        page = 1 if page <= 0

        raw_per_page = params[:per_page].to_i
        per_page = raw_per_page.positive? ? raw_per_page.clamp(1, max_per_page) : default_per_page

        total = records.size
        start_index = (page - 1) * per_page
        paged_records = records.slice(start_index, per_page) || []

        {
          records: paged_records,
          pagination: {
            page: page,
            per_page: per_page,
            total: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }
      end
    end
  end
end
