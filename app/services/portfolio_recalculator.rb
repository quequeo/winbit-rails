require 'bigdecimal'

# Rebuilds an investor portfolio snapshot from completed PortfolioHistory events.
# This is critical when you "backfill" a movement in the past (deposit/withdrawal/operating/trading fee)
# because it guarantees:
# - PortfolioHistory.previous_balance/new_balance are consistent in chronological order
# - Portfolio.current_balance / total_invested / accumulated returns match the replayed history
#
# `total_invested` = ingresos del inversor acumulados (depósitos + comisiones referido − reversos de depósito).
# Los retiros **no** restan de `total_invested` (no es “depósitos − retiros”).
class PortfolioRecalculator
  # Totales brutos + `total_invested` (solo ingresos, sin restar retiros).
  def self.total_invested_breakdown(investor_id)
    scope = PortfolioHistory.where(investor_id: investor_id, status: 'COMPLETED')
    deposits_sum = scope.where(event: 'DEPOSIT').sum(:amount)
    deposit_reversals_sum = scope.where(event: 'DEPOSIT_REVERSAL').sum(:amount)
    withdrawals_sum = scope.where(event: 'WITHDRAWAL').sum(:amount)
    referral_sum = scope.where(event: 'REFERRAL_COMMISSION').sum(:amount)

    total_invested = (
      BigDecimal(deposits_sum.to_s) +
      BigDecimal(referral_sum.to_s) -
      BigDecimal(deposit_reversals_sum.to_s)
    ).round(2, :half_up)
    total_invested = [total_invested, BigDecimal('0')].max

    {
      deposits_sum: BigDecimal(deposits_sum.to_s),
      deposit_reversals_sum: BigDecimal(deposit_reversals_sum.to_s),
      withdrawals_sum: BigDecimal(withdrawals_sum.to_s),
      referral_sum: BigDecimal(referral_sum.to_s),
      total_invested: total_invested,
    }
  end

  # Bloquea si `total_invested` (ingresos netos) quedaría negativo (reversos > depósitos+referidos).
  def self.negative_total_invested_blocking_message(investors)
    details = []
    investors.each do |inv|
      next unless inv.portfolio

      total = total_invested_breakdown(inv.id)[:total_invested]
      next unless total.negative?

      details << "#{inv.email} (total implícito #{total.to_f})"
    end
    return nil if details.empty?

    'El historial deja "total invertido" (ingresos) negativo para: ' + details.join('; ') +
      '. Corregí movimientos o ejecutá `bin/rails portfolios:audit_negative_total_invested`.'
  end

  def self.recalculate!(investor)
    portfolio = investor.portfolio || Portfolio.create!(investor: investor)

    histories = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED').order(:date, :created_at)

    running = BigDecimal('0')
    histories.each do |h|
      prev = running

      amt = BigDecimal(h.amount.to_s)
      delta =
        case h.event
        when 'WITHDRAWAL', 'DEPOSIT_REVERSAL'
          -amt.abs
        when 'TRADING_FEE'
          -amt.abs
        else
          amt
        end

      running = (running + delta).round(2, :half_up)
      h.update!(previous_balance: prev.to_f, new_balance: running.to_f)
    end

    breakdown = total_invested_breakdown(investor.id)
    total_invested = breakdown[:total_invested]

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
