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

      def history
        email = CGI.unescape(params[:email].to_s)

        investor = find_investor_by_email(email: email, message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        fees = investor.trading_fees.order(applied_at: :desc).to_a

        histories = investor.portfolio_histories.order(date: :desc).map { |h|
          extra = {}

          if h.event == 'TRADING_FEE'
            fee = find_trading_fee_for_history(fees, h)
            if fee
              extra[:tradingFeePeriodLabel] = fee.source == 'WITHDRAWAL' ? 'Retiro' : quarter_label(fee.period_end)
              extra[:tradingFeePeriodStart] = fee.period_start
              extra[:tradingFeePeriodEnd] = fee.period_end
              profit = fee.profit_amount.to_f
              extra[:tradingFeePercentage] = profit.positive? ? (h.amount.to_f.abs / profit * 100).round(2) : fee.fee_percentage.to_f
              extra[:tradingFeeSource] = fee.source
              extra[:tradingFeeWithdrawalAmount] = fee.withdrawal_amount.to_f if fee.source == 'WITHDRAWAL'
            end
          end

          if h.event == 'TRADING_FEE_ADJUSTMENT'
            fee = find_trading_fee_for_adjustment(fees, h)
            if fee
              extra[:tradingFeePeriodLabel] = quarter_label(fee.period_end)
              extra[:tradingFeePercentage] = fee.fee_percentage.to_f
            end
          end

          PublicPortfolioHistoryItemSerializer.new(h, extra: extra).as_json
        }

        requests = investor.investor_requests.where(status: ['PENDING', 'REJECTED']).order(requested_at: :desc).map { |r|
          PublicPendingRequestHistoryItemSerializer.new(r).as_json
        }

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

        fees.find do |f|
          (f.applied_at.to_i - ts).abs <= 600
        end
      end

      def find_trading_fee_for_adjustment(fees, history)
        ts = history.date.to_time.to_i

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
