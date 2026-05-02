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
      # Prefer portfolio snapshot (Genesis sheet + DailyOperatingResultApplicator compounding) when set;
      # otherwise fall back to TWR replay from PortfolioHistory.
      strategyReturnYtdUSD: p.strategy_return_ytd_usd.nil? ? ytd_return.pnl_usd : p.strategy_return_ytd_usd.to_f,
      strategyReturnYtdPercent: p.strategy_return_ytd_percent.nil? ? ytd_return.twr_percent : p.strategy_return_ytd_percent.to_f,
      strategyReturnYtdFrom: ytd_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      strategyReturnAllUSD: p.strategy_return_all_usd.nil? ? all_return.pnl_usd : p.strategy_return_all_usd.to_f,
      strategyReturnAllPercent: p.strategy_return_all_percent.nil? ? all_return.twr_percent : p.strategy_return_all_percent.to_f,
      strategyReturnAllFrom: all_return.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      updatedAt: p.updated_at
    }
  end
end
