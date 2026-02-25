module Api
  module Public
    class InvestorsController < BaseController
      def show
        email = CGI.unescape(params[:email].to_s)

        investor = find_investor_by_email(email: email, includes: [:portfolio], message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        now = Time.current
        year_start = Time.zone.local(Date.current.year, 1, 1, 0, 0, 0)

        ytd_return = TimeWeightedReturnCalculator.for_investor(investor_id: investor.id, from: year_start, to: now)
        all_return = TimeWeightedReturnCalculator.for_investor(investor_id: investor.id, from: nil, to: now)

        render json: {
          data: PublicInvestorShowSerializer.new(
            investor: investor,
            formatted_name: format_name(investor.name),
            ytd_return: ytd_return,
            all_return: all_return
          ).as_json
        }
      end

      def withdrawal_fee_preview
        email = CGI.unescape(params[:email].to_s)

        investor = find_investor_by_email(email: email, includes: [:portfolio], message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        amount = BigDecimal(params[:amount].to_s)
        if amount <= 0
          render json: { error: 'El monto debe ser mayor a cero' }, status: :unprocessable_entity
          return
        end

        portfolio = investor.portfolio
        unless portfolio
          render json: { error: 'Portfolio no encontrado' }, status: :not_found
          return
        end

        current_balance = BigDecimal(portfolio.current_balance.to_s)
        if amount > current_balance
          render json: { error: 'El monto supera el saldo disponible' }, status: :unprocessable_entity
          return
        end

        pending_profit = preview_pending_profit(investor)
        fee_percentage = BigDecimal(investor.trading_fee_percentage.to_s)

        realized_profit = BigDecimal('0')
        fee_amount = BigDecimal('0')

        if pending_profit.positive? && current_balance.positive?
          realized_profit = (pending_profit * (amount / current_balance)).round(2, :half_up)
          fee_amount = (realized_profit * (fee_percentage / 100)).round(2, :half_up)
        end

        render json: {
          data: {
            withdrawalAmount: amount.to_f,
            feeAmount: fee_amount.to_f,
            feePercentage: fee_percentage.to_f,
            realizedProfit: realized_profit.to_f,
            pendingProfit: pending_profit.to_f,
            hasFee: fee_amount.positive?
          }
        }
      rescue ArgumentError
        render json: { error: 'Monto inválido' }, status: :unprocessable_entity
      end

      def history
        email = CGI.unescape(params[:email].to_s)

        investor = find_investor_by_email(email: email, message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        fees = investor.trading_fees.order(applied_at: :desc).to_a
        approved_requests = investor.investor_requests
                                    .where(status: 'APPROVED')
                                    .select(:id, :request_type, :method, :processed_at)
                                    .to_a

        histories = investor.portfolio_histories.order(date: :desc).map { |h|
          extra = {}

          if %w[WITHDRAWAL DEPOSIT].include?(h.event)
            req = find_request_for_history(approved_requests, h)
            extra[:method] = req&.method
          end

          if h.event == 'TRADING_FEE'
            fee = find_trading_fee_for_history(fees, h)
            if fee
              extra[:tradingFeePeriodLabel] = fee.source == 'WITHDRAWAL' ? 'Retiro' : period_label(fee)
              extra[:tradingFeePeriodStart] = fee.period_start
              extra[:tradingFeePeriodEnd] = fee.period_end
              extra[:tradingFeePercentage] = fee.fee_percentage.to_f
              extra[:tradingFeeSource] = fee.source
              extra[:tradingFeeWithdrawalAmount] = fee.withdrawal_amount.to_f if fee.source == 'WITHDRAWAL'
            end
          end

          if h.event == 'TRADING_FEE_ADJUSTMENT'
            fee = find_trading_fee_for_adjustment(fees, h)
            if fee
              extra[:tradingFeePeriodLabel] = period_label(fee)
              extra[:tradingFeePercentage] = fee.fee_percentage.to_f
            end
          end

          PublicPortfolioHistoryItemSerializer.new(h, extra: extra).as_json
        }

        requests = investor.investor_requests.where(status: ['PENDING', 'REJECTED']).order(requested_at: :desc).map { |r|
          PublicPendingRequestHistoryItemSerializer.new(r).as_json
        }

        combined = (histories + requests).sort_by do |item|
          d = item[:date]
          t = d.respond_to?(:to_time) ? d.to_time : Time.zone.parse(d.to_s)
          # Cuando retiro y comisión tienen la misma fecha, mostrar retiro antes que la comisión
          sort_key = (item[:event] == 'TRADING_FEE' && item[:tradingFeeSource] == 'WITHDRAWAL') ? 1 : 0
          [-t.to_f, sort_key]
        end

        render json: { data: combined }
      end

      private

      def period_label(fee)
        start_d = fee.period_start.to_date
        end_d = fee.period_end.to_date
        if start_d.month == end_d.month && start_d.year == end_d.year
          "#{end_d.year}-#{format('%02d', end_d.month)}"
        else
          q = ((end_d.month - 1) / 3) + 1
          "Q#{q} #{end_d.year}"
        end
      end

      def find_trading_fee_for_history(fees, history)
        ts = history.date.to_time
        amount_abs = history.amount.to_d.abs

        # Prefer matching by amount: PH.amount = -fee_amount, so fee_amount should match history.amount.abs
        # This avoids wrong matches when multiple fees exist in the same 10-min window (e.g. withdrawal + periodic)
        by_amount = fees.select do |f|
          (f.fee_amount.to_d - amount_abs).abs < BigDecimal('0.01') &&
            (f.applied_at.to_i - ts.to_i).abs <= 600
        end

        return by_amount.min_by { |f| (f.applied_at - ts).abs } if by_amount.any?

        # Fallback: timestamp only (legacy or rounding edge cases)
        fees.find { |f| (f.applied_at.to_i - ts.to_i).abs <= 600 }
      end

      def find_request_for_history(requests, history)
        ts = history.date.to_time.to_i
        requests.find { |r| r.request_type == history.event && (r.processed_at.to_i - ts).abs <= 600 }
      end

      def find_trading_fee_for_adjustment(fees, history)
        ts = history.date.to_time.to_i

        fees.find do |f|
          (f.updated_at.to_i - ts).abs <= 600 || (f.voided_at && (f.voided_at.to_i - ts).abs <= 600)
        end
      end

      def preview_pending_profit(investor)
        operating_profit = PortfolioHistory
          .where(investor_id: investor.id, event: 'OPERATING_RESULT', status: 'COMPLETED')
          .sum(:amount)
        fee_profit = TradingFee.active.where(investor_id: investor.id).sum(:profit_amount)
        pending = BigDecimal(operating_profit.to_s) - BigDecimal(fee_profit.to_s)
        pending.positive? ? pending : BigDecimal('0')
      end

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
