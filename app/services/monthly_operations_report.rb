# frozen_string_literal: true

# Firm-wide "Operaciones del mes" data (StrategyOperation trades + summary
# stats) for a given month - identical for every investor, since trades are
# not scoped to an investor. Shared by InvestorMonthlyReportPdfs::DocumentData
# (PDF) and Api::Admin::InvestorMonthlyReportsController (on-screen report /
# Excel export), so both surfaces show exactly the same operations data.
class MonthlyOperationsReport
  Trade = Struct.new(
    :date, :asset, :direction, :opened_at, :closed_at,
    :result_usd, :result_percent, :ratio,
    keyword_init: true
  )

  Result = Struct.new(:trades, :assets, :count, :positive, :negative, :break_even, :net_result_usd, keyword_init: true)

  def self.call(month:)
    new(month:).call
  end

  def initialize(month:)
    @month = month.is_a?(String) ? Date.strptime("#{month}-01", '%Y-%m-%d') : month.to_date.beginning_of_month
  end

  def call
    trades = operations.map { |op| build_trade(op) }

    Result.new(
      trades: trades,
      assets: asset_chips,
      count: trades.size,
      positive: trades.count { |t| t.result_usd.to_f.positive? },
      negative: trades.count { |t| t.result_usd.to_f.negative? },
      break_even: trades.count { |t| t.result_usd.to_f.zero? },
      net_result_usd: trades.sum { |t| t.result_usd.to_f },
    )
  end

  private

  def operations
    @operations ||= StrategyOperation
                    .where(operation_date: @month.beginning_of_month..@month.end_of_month)
                    .order(:operation_date, :opened_at)
  end

  # DailyOperatingResult holds the firm-wide daily percent return that was
  # actually applied to every investor's balance that day (one row per
  # date, same source DailyOperatingResultApplicator/PortfolioHistory use).
  # StrategyOperation doesn't store a percent of its own.
  def daily_percents_by_date
    @daily_percents_by_date ||= DailyOperatingResult
                                 .where(date: @month.beginning_of_month..@month.end_of_month)
                                 .pluck(:date, :percent).to_h
  end

  def build_trade(op)
    Trade.new(
      date: op.operation_date,
      asset: op.asset,
      direction: op.direction,
      opened_at: op.opened_at,
      closed_at: op.closed_at,
      result_usd: op.result_usd.to_f,
      result_percent: daily_percents_by_date[op.operation_date]&.to_f,
      ratio: op.ratio&.to_f,
    )
  end

  def asset_chips
    operations.map(&:asset).uniq.map { |code| { code: code, name: StrategyOperation::ASSET_NAMES[code] || code } }
  end
end
