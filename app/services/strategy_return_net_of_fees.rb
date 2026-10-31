# frozen_string_literal: true

require 'bigdecimal'

# Nets the trading fees paid in a window out of a gross strategy return.
#
# Portfolio#strategy_return_ytd_*/strategy_return_all_* compound daily from
# DailyOperatingResult and never see TRADING_FEE, so they are always gross.
# Every figure shown to an investor or an admin is net of the service cost:
# USD is the gross minus the fees paid in the same window, and the percent is
# that net USD over the same capital base implied by the gross pair.
class StrategyReturnNetOfFees
  def self.call(investor_id:, gross_usd:, gross_percent:, from:, to:)
    gross_usd = BigDecimal(gross_usd.to_s)
    gross_percent = BigDecimal(gross_percent.to_s)

    fees = InvestorTradingFeesPaid.total(investor_id: investor_id, from: from, to: to)
    net_usd = (gross_usd - fees).round(2, :half_up)

    net_percent =
      if gross_percent.zero? || gross_usd.zero?
        BigDecimal('0')
      else
        base_capital = gross_usd / (gross_percent / 100)
        base_capital.positive? ? ((net_usd / base_capital) * 100).round(4, :half_up) : BigDecimal('0')
      end

    { usd: net_usd.to_f, percent: net_percent.to_f }
  end
end
