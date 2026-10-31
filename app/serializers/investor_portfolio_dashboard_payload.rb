# frozen_string_literal: true

class InvestorPortfolioDashboardPayload
  def self.build(investor:)
    new(investor:).build
  end

  def initialize(investor:)
    @investor = investor
  end

  def build
    portfolio = investor.portfolio
    return nil unless portfolio

    ytd_net = net_of_fees(
      stored: !portfolio.strategy_return_ytd_usd.nil?,
      gross_usd: strategy_ytd_usd(portfolio), gross_percent: strategy_ytd_percent(portfolio),
      from: Time.zone.local(Date.current.year, 1, 1, 0, 0, 0)
    )
    all_net = net_of_fees(
      stored: !portfolio.strategy_return_all_usd.nil?,
      gross_usd: strategy_all_usd(portfolio), gross_percent: strategy_all_percent(portfolio),
      from: nil
    )

    {
      currentBalance: portfolio.current_balance.to_f,
      totalInvested: portfolio.total_invested.to_f,
      accumulatedReturnUSD: portfolio.accumulated_return_usd.to_f,
      accumulatedReturnPercent: portfolio.accumulated_return_percent.to_f,
      annualReturnUSD: portfolio.annual_return_usd.to_f,
      annualReturnPercent: portfolio.annual_return_percent.to_f,
      strategyReturnYtdUSD: strategy_ytd_usd(portfolio),
      strategyReturnYtdPercent: strategy_ytd_percent(portfolio),
      strategyReturnYtdNetUSD: ytd_net[:usd],
      strategyReturnYtdNetPercent: ytd_net[:percent],
      strategyReturnYtdFrom: ytd_return&.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      strategyReturnAllUSD: strategy_all_usd(portfolio),
      strategyReturnAllPercent: strategy_all_percent(portfolio),
      strategyReturnAllNetUSD: all_net[:usd],
      strategyReturnAllNetPercent: all_net[:percent],
      strategyReturnAllFrom: all_return&.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      updatedAt: portfolio.updated_at,
    }
  end

  private

  attr_reader :investor

  # The stored strategy_return_* figures are gross (they compound daily and
  # never see TRADING_FEE). The TimeWeightedReturnCalculator fallback already
  # counts fees as performance, so it is net as is - netting it again would
  # charge the service cost twice.
  def net_of_fees(stored:, gross_usd:, gross_percent:, from:)
    return { usd: gross_usd.to_f, percent: gross_percent.to_f } unless stored

    StrategyReturnNetOfFees.call(
      investor_id: investor.id, gross_usd: gross_usd, gross_percent: gross_percent,
      from: from, to: Time.current
    )
  end

  def strategy_ytd_usd(portfolio)
    return portfolio.strategy_return_ytd_usd.to_f unless portfolio.strategy_return_ytd_usd.nil?

    ytd_return.pnl_usd
  end

  def strategy_ytd_percent(portfolio)
    return portfolio.strategy_return_ytd_percent.to_f unless portfolio.strategy_return_ytd_percent.nil?

    ytd_return.twr_percent
  end

  def strategy_all_usd(portfolio)
    return portfolio.strategy_return_all_usd.to_f unless portfolio.strategy_return_all_usd.nil?

    all_return.pnl_usd
  end

  def strategy_all_percent(portfolio)
    return portfolio.strategy_return_all_percent.to_f unless portfolio.strategy_return_all_percent.nil?

    all_return.twr_percent
  end

  def ytd_return
    return @ytd_return if defined?(@ytd_return)

    portfolio = investor.portfolio
    needs_ytd = portfolio.strategy_return_ytd_usd.nil? || portfolio.strategy_return_ytd_percent.nil?
    unless needs_ytd
      @ytd_return = nil
      return @ytd_return
    end

    @ytd_return = TimeWeightedReturnCalculator.for_investor(
      investor_id: investor.id,
      from: Time.zone.local(Date.current.year, 1, 1, 0, 0, 0),
      to: Time.current,
    )
  end

  def all_return
    return @all_return if defined?(@all_return)

    portfolio = investor.portfolio
    needs_all = portfolio.strategy_return_all_usd.nil? || portfolio.strategy_return_all_percent.nil?
    unless needs_all
      @all_return = nil
      return @all_return
    end

    @all_return = TimeWeightedReturnCalculator.for_investor(
      investor_id: investor.id,
      from: nil,
      to: Time.current,
    )
  end
end
