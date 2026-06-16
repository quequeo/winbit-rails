class AdminDashboardSerializer
  def initialize(
    investor_count:,
    pending_request_count:,
    total_aum:,
    aum_series:,
    strategy_return_ytd_usd:,
    strategy_return_ytd_percent:,
    strategy_return_all_usd:,
    strategy_return_all_percent:,
    operating_return_month_usd:,
    operating_return_month_percent:,
    net_deposits_usd:,
    net_withdrawals_usd:,
    net_flows_usd:,
    alerts:,
    aum_concentration:
  )
    @investor_count = investor_count
    @pending_request_count = pending_request_count
    @total_aum = total_aum
    @aum_series = aum_series
    @strategy_return_ytd_usd = strategy_return_ytd_usd
    @strategy_return_ytd_percent = strategy_return_ytd_percent
    @strategy_return_all_usd = strategy_return_all_usd
    @strategy_return_all_percent = strategy_return_all_percent
    @operating_return_month_usd = operating_return_month_usd
    @operating_return_month_percent = operating_return_month_percent
    @net_deposits_usd = net_deposits_usd
    @net_withdrawals_usd = net_withdrawals_usd
    @net_flows_usd = net_flows_usd
    @alerts = alerts
    @aum_concentration = aum_concentration
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
      strategyReturnAllPercent: @strategy_return_all_percent,
      operatingReturnMonthUsd: @operating_return_month_usd,
      operatingReturnMonthPercent: @operating_return_month_percent,
      netDepositsUsd: @net_deposits_usd,
      netWithdrawalsUsd: @net_withdrawals_usd,
      netFlowsUsd: @net_flows_usd,
      alerts: @alerts,
      aumConcentration: @aum_concentration,
    }
  end
end
