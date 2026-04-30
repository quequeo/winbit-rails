class PublicInvestorShowSerializer
  def initialize(investor:, formatted_name:, ytd_return:, all_return:)
    @investor = investor
    @formatted_name = formatted_name
    @ytd_return = ytd_return
    @all_return = all_return
  end

  def as_json(*)
    {
      investor: {
        email: investor.email,
        name: formatted_name
      },
      portfolio: portfolio_payload
    }
  end

  private

  attr_reader :investor, :formatted_name, :ytd_return, :all_return

  def portfolio_payload
    return nil unless investor.portfolio

    p = investor.portfolio

    {
      currentBalance: p.current_balance.to_f,
      totalInvested: p.total_invested.to_f,
      accumulatedReturnUSD: p.accumulated_return_usd.to_f,
      accumulatedReturnPercent: p.accumulated_return_percent.to_f,
      annualReturnUSD: p.annual_return_usd.to_f,
      annualReturnPercent: p.annual_return_percent.to_f,
      # Always expose net strategy result from historical replay.
      # This includes internal events like TRADING_FEE and avoids stale cached fields.
      strategyReturnYtdUSD: ytd_return.pnl_usd,
      strategyReturnYtdPercent: ytd_return.twr_percent,
      strategyReturnYtdFrom: ytd_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      strategyReturnAllUSD: all_return.pnl_usd,
      strategyReturnAllPercent: all_return.twr_percent,
      strategyReturnAllFrom: all_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      updatedAt: p.updated_at
    }
  end
end
