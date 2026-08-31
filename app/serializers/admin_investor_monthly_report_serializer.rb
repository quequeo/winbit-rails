# frozen_string_literal: true

class AdminInvestorMonthlyReportSerializer
  def initialize(report, operations: nil)
    @report = report
    @operations = operations
  end

  def as_json
    {
      investor: {
        id: @report.dig(:investor, :id),
        name: @report.dig(:investor, :name),
        email: @report.dig(:investor, :email),
      },
      reportMonth: @report[:report_month],
      summary: {
        portfolioValueUsd: @report.dig(:summary, :portfolio_value_usd),
        netContributedUsd: @report.dig(:summary, :net_contributed_usd),
        winbitMonthlyReturnPercent: @report.dig(:summary, :winbit_monthly_return_percent),
        accumulatedSinceEntryUsd: @report.dig(:summary, :accumulated_since_entry_usd),
        accumulatedSinceEntryPercent: @report.dig(:summary, :accumulated_since_entry_percent),
        accumulated2026Usd: @report.dig(:summary, :accumulated_2026_usd),
        accumulated2026Percent: @report.dig(:summary, :accumulated_2026_percent),
        yearOpeningDate: @report.dig(:summary, :year_opening_date),
        yearOpeningBalanceUsd: @report.dig(:summary, :year_opening_balance_usd),
      },
      annexRows: (@report[:annex_rows] || []).map { |row| serialize_annex_row(row) },
      operations: @operations && serialize_operations(@operations),
    }
  end

  private

  def serialize_annex_row(row)
    {
      month: row[:month],
      label: row[:label],
      returnPercent: row[:return_percent],
      returnUsd: row[:return_usd],
      deposits: row[:deposits],
      withdrawals: row[:withdrawals],
      serviceCost: row[:service_cost],
      portfolioValue: row[:portfolio_value],
      openingSnapshot: row[:opening_snapshot],
      entryRow: row[:entry_row],
      source: row[:source],
    }
  end

  def serialize_operations(operations)
    {
      trades: operations.trades.map { |t| serialize_trade(t) },
      assets: operations.assets,
      count: operations.count,
      positive: operations.positive,
      negative: operations.negative,
      breakEven: operations.break_even,
      netResultUsd: operations.net_result_usd,
    }
  end

  def serialize_trade(trade)
    {
      date: trade.date,
      asset: trade.asset,
      direction: trade.direction,
      openedAt: trade.opened_at,
      closedAt: trade.closed_at,
      resultUsd: trade.result_usd,
      resultPercent: trade.result_percent,
      ratio: trade.ratio,
    }
  end
end
