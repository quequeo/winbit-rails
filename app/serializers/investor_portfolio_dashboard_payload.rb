# frozen_string_literal: true

# Portfolio figures shown in the admin's Inversores tab and in the investor
# app. Every return here is net of the service cost and comes from
# MonthlyReportBuilder for the current month - the same calculation as the
# monthly PDF - so the three always show the same numbers.
class InvestorPortfolioDashboardPayload
  def self.build(investor:)
    new(investor:).build
  end

  # Raw stored/gross figures only. MonthlyReportBuilder starts from these, so
  # it can't go through #build (which itself runs the builder).
  def self.gross(investor:)
    new(investor:).gross
  end

  def initialize(investor:)
    @investor = investor
  end

  def build
    payload = gross
    return nil unless payload

    report = MonthlyReportBuilder.new(investor: investor, report_month: Date.current).build
    summary = report[:summary]
    month_row = report[:month_row]

    payload.merge(
      netContributedUSD: summary[:net_contributed_after_withdrawals_usd].to_f,
      monthReturnNetUSD: month_row&.dig(:return_usd).to_f,
      monthReturnNetPercent: month_row&.dig(:return_percent).to_f,
      strategyReturnYtdNetUSD: summary[:accumulated_2026_usd].to_f,
      strategyReturnYtdNetPercent: summary[:accumulated_2026_percent].to_f,
      strategyReturnAllNetUSD: summary[:accumulated_since_entry_usd].to_f,
      strategyReturnAllNetPercent: summary[:accumulated_since_entry_percent].to_f,
    )
  end

  def gross
    portfolio = investor.portfolio
    return nil unless portfolio

    {
      currentBalance: portfolio.current_balance.to_f,
      totalInvested: portfolio.total_invested.to_f,
      accumulatedReturnUSD: portfolio.accumulated_return_usd.to_f,
      accumulatedReturnPercent: portfolio.accumulated_return_percent.to_f,
      annualReturnUSD: portfolio.annual_return_usd.to_f,
      annualReturnPercent: portfolio.annual_return_percent.to_f,
      strategyReturnYtdUSD: strategy_ytd_usd(portfolio),
      strategyReturnYtdPercent: strategy_ytd_percent(portfolio),
      strategyReturnYtdFrom: ytd_return&.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      strategyReturnAllUSD: strategy_all_usd(portfolio),
      strategyReturnAllPercent: strategy_all_percent(portfolio),
      strategyReturnAllFrom: all_return&.effective_start_at&.to_date&.strftime('%Y-%m-%d'),
      updatedAt: portfolio.updated_at,
    }
  end

  private

  attr_reader :investor

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
