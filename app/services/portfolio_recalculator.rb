require 'bigdecimal'

# Rebuilds an investor portfolio snapshot from completed PortfolioHistory events.
# This is critical when you "backfill" a movement in the past (deposit/withdrawal/operating/trading fee)
# because it guarantees:
# - PortfolioHistory.previous_balance/new_balance are consistent in chronological order
# - Portfolio.current_balance / total_invested / accumulated returns match the replayed history
class PortfolioRecalculator
  def self.recalculate!(investor)
    portfolio = investor.portfolio || Portfolio.create!(investor: investor)

    histories = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED').order(:date, :created_at)

    running = BigDecimal('0')
    histories.each do |h|
      prev = running

      amt = BigDecimal(h.amount.to_s)
      delta =
        case h.event
        when 'WITHDRAWAL'
          -amt.abs
        when 'TRADING_FEE'
          -amt.abs
        else
          amt
        end

      running = (running + delta).round(2, :half_up)
      h.update!(previous_balance: prev.to_f, new_balance: running.to_f)
    end

    deposits_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'DEPOSIT').sum(:amount)
    withdrawals_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'WITHDRAWAL').sum(:amount)
    total_invested = (BigDecimal(deposits_sum.to_s) - BigDecimal(withdrawals_sum.to_s)).round(2, :half_up)

    acc_usd = (running - total_invested).round(2, :half_up)
    acc_pct = total_invested.positive? ? ((acc_usd / total_invested) * 100).round(4, :half_up) : BigDecimal('0')

    portfolio.update!(
      current_balance: running.to_f,
      total_invested: total_invested.to_f,
      accumulated_return_usd: acc_usd.to_f,
      accumulated_return_percent: acc_pct.to_f,
    )
  end
end
