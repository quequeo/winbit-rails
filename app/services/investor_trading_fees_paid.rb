# frozen_string_literal: true

require 'bigdecimal'

# Total trading fees actually deducted from an investor's balance in a window,
# net of any TRADING_FEE_ADJUSTMENT (refund/correction). Sources from
# PortfolioHistory (what actually moved the balance) rather than the TradingFee
# ledger table, which can be missing rows for fees applied outside the normal
# TradingFeeApplicator flow (e.g. historical/genesis-era charges).
class InvestorTradingFeesPaid
  FEE_EVENTS = %w[TRADING_FEE TRADING_FEE_ADJUSTMENT].freeze

  def self.total(investor_id:, from: nil, to: Time.current)
    scope = PortfolioHistory.where(investor_id: investor_id, event: FEE_EVENTS, status: 'COMPLETED')
    scope = scope.where('date <= ?', to)
    scope = scope.where('date >= ?', from) if from

    # TRADING_FEE is stored negative (a charge); TRADING_FEE_ADJUSTMENT offsets it
    # (typically positive, a refund). Negate the sum so a net charge comes back positive.
    -(BigDecimal(scope.sum(:amount).to_s))
  end
end
