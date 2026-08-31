# frozen_string_literal: true

# Per-investor "Operaciones del mes" data: for each date the investor had an
# OPERATING_RESULT in their own PortfolioHistory, look up that date's
# StrategyOperation for the trade's identity (asset/direction/times/ratio)
# and pair it with the investor's own dollar result for that day - the same
# figures already shown in their portal history
# (Public::StrategyOperationHistoryEnrichment). This means an investor who
# joined mid-month automatically only sees operations from their own entry
# date onward, since there's no OPERATING_RESULT for them before that.
#
# "RENDIMIENTO %" is the firm-wide daily percent (DailyOperatingResult),
# identical for every investor - only the dollar result and which dates
# appear are investor-specific.
class MonthlyOperationsReport
  Trade = Struct.new(
    :date, :asset, :direction, :opened_at, :closed_at,
    :result_usd, :result_percent, :ratio, :result_label,
    keyword_init: true
  )

  Result = Struct.new(:trades, :assets, :count, :positive, :negative, :break_even, :net_result_usd, keyword_init: true)

  def self.call(investor:, month:)
    new(investor:, month:).call
  end

  def initialize(investor:, month:)
    @investor = investor
    @month = month.is_a?(String) ? Date.strptime("#{month}-01", '%Y-%m-%d') : month.to_date.beginning_of_month
  end

  def call
    trades = daily_results.filter_map { |date, amount| build_trade(date, amount) }.sort_by(&:date)

    # Classify by the trade's own result_label (POSITIVO/NEGATIVO/BE+/BE-),
    # not the sign of this investor's dollar amount - a trade the system
    # calls break-even can still net a small negative $ for a given investor
    # (e.g. proportional CST/rounding), and that shouldn't count as a loss.
    Result.new(
      trades: trades,
      assets: asset_chips(trades),
      count: trades.size,
      positive: trades.count { |t| t.result_label == 'POSITIVO' },
      negative: trades.count { |t| t.result_label == 'NEGATIVO' },
      break_even: trades.count { |t| %w[BE+ BE-].include?(t.result_label) },
      net_result_usd: trades.sum(&:result_usd),
    )
  end

  private

  # This investor's own daily $ result for the month.
  def daily_results
    @daily_results ||= @investor.portfolio_histories
                                 .where(event: 'OPERATING_RESULT', date: @month.beginning_of_month..@month.end_of_month)
                                 .pluck(:date, :amount)
                                 .map { |date, amount| [date.to_date, amount.to_f] }
  end

  def operations_by_date
    @operations_by_date ||= StrategyOperation
                            .where(operation_date: daily_results.map(&:first))
                            .index_by(&:operation_date)
  end

  # DailyOperatingResult holds the firm-wide daily percent return that was
  # actually applied to every investor's balance that day (one row per
  # date, same source DailyOperatingResultApplicator/PortfolioHistory use).
  def daily_percents_by_date
    @daily_percents_by_date ||= DailyOperatingResult
                                 .where(date: @month.beginning_of_month..@month.end_of_month)
                                 .pluck(:date, :percent).to_h
  end

  def build_trade(date, amount)
    op = operations_by_date[date]
    return nil unless op

    Trade.new(
      date: date,
      asset: op.asset,
      direction: op.direction,
      opened_at: op.opened_at,
      closed_at: op.closed_at,
      result_usd: amount,
      result_percent: daily_percents_by_date[date]&.to_f,
      ratio: op.ratio&.to_f,
      result_label: op.result_label,
    )
  end

  def asset_chips(trades)
    trades.map(&:asset).uniq.map { |code| { code: code, name: StrategyOperation::ASSET_NAMES[code] || code } }
  end
end
