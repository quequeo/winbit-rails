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

    {
      currentBalance: investor.portfolio.current_balance.to_f,
      totalInvested: investor.portfolio.total_invested.to_f,
      accumulatedReturnUSD: investor.portfolio.accumulated_return_usd.to_f,
      accumulatedReturnPercent: investor.portfolio.accumulated_return_percent.to_f,
      annualReturnUSD: investor.portfolio.annual_return_usd.to_f,
      annualReturnPercent: investor.portfolio.annual_return_percent.to_f,
      strategyReturnYtdUSD: ytd_return.pnl_usd,
      strategyReturnYtdPercent: ytd_return.twr_percent,
      strategyReturnYtdFrom: ytd_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      strategyReturnAllUSD: all_return.pnl_usd,
      strategyReturnAllPercent: all_return.twr_percent,
      strategyReturnAllFrom: all_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      updatedAt: investor.portfolio.updated_at
    }
  end
end
