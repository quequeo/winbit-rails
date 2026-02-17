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
            # Strategy return (TWR) - main metric for the portal
            strategyReturnYtdUSD: ytd_return.pnl_usd,
            strategyReturnYtdPercent: ytd_return.twr_percent,
            strategyReturnYtdFrom: ytd_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
            strategyReturnAllUSD: all_return.pnl_usd,
            strategyReturnAllPercent: all_return.twr_percent,
            strategyReturnAllFrom: all_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
            updatedAt: investor.portfolio.updated_at,
          } : nil,
        }

        render json: { data: response }
      end

      def history
        email = CGI.unescape(params[:email].to_s)

        investor = find_investor_by_email(email: email, message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        # Portfolio histories (completed movements)
        fees = investor.trading_fees.order(applied_at: :desc).to_a

        histories = investor.portfolio_histories.order(date: :desc).map { |h|
          item = {
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

          if h.event == 'TRADING_FEE'
            fee = find_trading_fee_for_history(fees, h)
            if fee
              item[:tradingFeePeriodLabel] = quarter_label(fee.period_end)
              item[:tradingFeePeriodStart] = fee.period_start
              item[:tradingFeePeriodEnd] = fee.period_end
              # Calculate original % from history amount (fee may have been updated since)
              profit = fee.profit_amount.to_f
              item[:tradingFeePercentage] = profit.positive? ? (h.amount.to_f.abs / profit * 100).round(2) : fee.fee_percentage.to_f
            end
          end

          if h.event == 'TRADING_FEE_ADJUSTMENT'
            fee = find_trading_fee_for_adjustment(fees, h)
            if fee
              item[:tradingFeePeriodLabel] = quarter_label(fee.period_end)
              item[:tradingFeePercentage] = fee.fee_percentage.to_f
            end
          end

          item
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
            notes: r.notes,
          }
        }

        # Combine and sort by date
        combined = (histories + requests).sort_by { |item| item[:date] }.reverse

        render json: { data: combined }
      end

      private

      def quarter_label(date)
        d = date.to_date
        q = ((d.month - 1) / 3) + 1
        "Q#{q} #{d.year}"
      end

      def find_trading_fee_for_history(fees, history)
        ts = history.date.to_time.to_i

        # Match by applied_at proximity (amount may have changed if fee was later edited)
        fees.find do |f|
          (f.applied_at.to_i - ts).abs <= 600
        end
      end

      def find_trading_fee_for_adjustment(fees, history)
        ts = history.date.to_time.to_i

        # Match by updated_at or voided_at proximity (adjustments are created when fees are edited/voided)
        fees.find do |f|
          (f.updated_at.to_i - ts).abs <= 600 || (f.voided_at && (f.voided_at.to_i - ts).abs <= 600)
        end
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
