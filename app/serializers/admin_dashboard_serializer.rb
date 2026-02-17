class AdminDashboardSerializer
  def initialize(
    investor_count:,
    pending_request_count:,
    total_aum:,
    aum_series:,
    strategy_return_ytd_usd:,
    strategy_return_ytd_percent:,
    strategy_return_all_usd:,
    strategy_return_all_percent:
  )
    @investor_count = investor_count
    @pending_request_count = pending_request_count
    @total_aum = total_aum
    @aum_series = aum_series
    @strategy_return_ytd_usd = strategy_return_ytd_usd
    @strategy_return_ytd_percent = strategy_return_ytd_percent
    @strategy_return_all_usd = strategy_return_all_usd
    @strategy_return_all_percent = strategy_return_all_percent
  end

  def as_json(*)
    {
      investorCount: @investor_count,
      pendingRequestCount: @pending_request_count,
      totalAum: @total_aum.to_f,
      aumSeries: @aum_series,
      strategyReturnYtdUsd: @strategy_return_ytd_usd,
      strategyReturnYtdPercent: @strategy_return_ytd_percent,
      strategyReturnAllUsd: @strategy_return_all_usd,
      strategyReturnAllPercent: @strategy_return_all_percent
    }
  end
end
