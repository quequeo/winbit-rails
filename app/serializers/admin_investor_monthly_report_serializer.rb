# frozen_string_literal: true

class AdminInvestorMonthlyReportSerializer
  def initialize(report)
    @report = report
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
        winbitMonthlyReturnPercent: @report.dig(:summary, :winbit_monthly_return_percent),
        accumulatedSinceEntryUsd: @report.dig(:summary, :accumulated_since_entry_usd),
        accumulatedSinceEntryPercent: @report.dig(:summary, :accumulated_since_entry_percent),
        accumulated2026Usd: @report.dig(:summary, :accumulated_2026_usd),
        accumulated2026Percent: @report.dig(:summary, :accumulated_2026_percent),
      },
      annexRows: (@report[:annex_rows] || []).map { |row| serialize_annex_row(row) },
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
end
