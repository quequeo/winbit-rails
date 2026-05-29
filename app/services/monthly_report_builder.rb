# frozen_string_literal: true

require 'bigdecimal'

class MonthlyReportBuilder
  SPREADSHEET_LAST_MONTH = Date.new(2026, 4, 1)
  POST_GENESIS_FLOW_START = Time.zone.local(2026, 5, 4).beginning_of_day

  MONTH_LABELS = {
    '2025-12' => 'Dec-25',
    '2026-01' => 'Jan-26',
    '2026-02' => 'Feb-26',
    '2026-03' => 'Mar-26',
    '2026-04' => 'Apr-26',
    '2026-05' => 'May-26',
    '2026-06' => 'Jun-26',
    '2026-07' => 'Jul-26',
    '2026-08' => 'Aug-26',
    '2026-09' => 'Sep-26',
    '2026-10' => 'Oct-26',
    '2026-11' => 'Nov-26',
    '2026-12' => 'Dec-26',
  }.freeze

  def initialize(investor:, report_month:)
    @investor = investor
    @report_month = report_month.to_date.beginning_of_month
  end

  def build
    annex_rows = build_annex_rows
    dec_opening = annex_rows.find { |r| r[:opening_snapshot] }
    ytd_usd = compute_ytd_usd(annex_rows)
    ytd_base = dec_opening&.dig(:portfolio_value).to_f

    {
      investor: {
        id: @investor.id,
        name: @investor.name,
        email: @investor.email,
      },
      report_month: @report_month.strftime('%Y-%m'),
      summary: build_summary(annex_rows, ytd_usd, ytd_base),
      annex_rows: annex_rows,
    }
  end

  private

  def build_summary(annex_rows, ytd_usd, ytd_base)
    portfolio = @investor.portfolio
    end_value = portfolio_value_at_month_end(@report_month)

    {
      portfolio_value_usd: end_value,
      winbit_monthly_return_percent: winbit_monthly_percent(@report_month),
      accumulated_since_entry_usd: portfolio&.strategy_return_all_usd&.to_f,
      accumulated_since_entry_percent: portfolio&.strategy_return_all_percent&.to_f,
      accumulated_2026_usd: ytd_usd,
      accumulated_2026_percent: ytd_base.positive? ? ((ytd_usd / ytd_base) * 100).round(2) : nil,
    }
  end

  def build_annex_rows
    rows = spreadsheet_rows
    platform_start = SPREADSHEET_LAST_MONTH.next_month
    month = platform_start

    while month <= @report_month
      rows << build_platform_row(month, previous_row: rows.last)
      month = month.next_month
    end

    rows
  end

  def spreadsheet_rows
    @investor.investor_monthly_annex_rows.spreadsheet.ordered.map do |row|
      serialize_row(
        month: row.month,
        return_percent: row.return_percent&.to_f,
        return_usd: row.return_usd&.to_f,
        deposits: row.deposits.to_f,
        withdrawals: row.withdrawals.to_f,
        service_cost: row.service_cost.to_f,
        portfolio_value: row.portfolio_value&.to_f,
        opening_snapshot: row.opening_snapshot,
        source: row.source,
      )
    end
  end

  def build_platform_row(month, previous_row:)
    month_start = month.beginning_of_month
    month_end = effective_month_end(month)
    flow_start = flow_start_for(month, month_start)

    twr = TimeWeightedReturnCalculator.for_investor(
      investor_id: @investor.id,
      from: month_start.beginning_of_day,
      to: month_end,
    )

    flows = aggregate_flows(flow_start, month_end)
    end_value = portfolio_value_at(month_end)

    serialize_row(
      month: month,
      return_percent: twr.twr_percent,
      return_usd: twr.pnl_usd,
      deposits: flows[:deposits],
      withdrawals: flows[:withdrawals],
      service_cost: flows[:service_cost],
      portfolio_value: end_value,
      opening_snapshot: false,
      source: 'platform',
    )
  end

  def aggregate_flows(from_time, to_time)
    histories = PortfolioHistory
                .where(investor_id: @investor.id, status: 'COMPLETED')
                .where(date: from_time..to_time)

    deposits = bd('0')
    withdrawals = bd('0')
    service_cost = bd('0')

    histories.find_each do |h|
      amount = bd(h.amount.to_s).abs
      case h.event
      when 'DEPOSIT', 'REFERRAL_COMMISSION'
        deposits += amount
      when 'DEPOSIT_REVERSAL'
        deposits -= amount
      when 'WITHDRAWAL'
        withdrawals += amount
      when 'WITHDRAWAL_REVERSAL'
        withdrawals -= amount
      when 'TRADING_FEE'
        service_cost += amount
      end
    end

    {
      deposits: deposits.round(2).to_f,
      withdrawals: withdrawals.round(2).to_f,
      service_cost: service_cost.round(2).to_f,
    }
  end

  def flow_start_for(month, month_start)
    return POST_GENESIS_FLOW_START if month == Date.new(2026, 5, 1)

    month_start.beginning_of_day
  end

  def effective_month_end(month)
    if month == Date.current.beginning_of_month
      Time.current
    else
      month.end_of_month.end_of_day
    end
  end

  def portfolio_value_at(time)
    last = PortfolioHistory
           .where(investor_id: @investor.id, status: 'COMPLETED')
           .where('date <= ?', time)
           .order(date: :desc, created_at: :desc)
           .limit(1)
           .pick(:new_balance)

    return last.to_f if last

    annex_value = @investor.investor_monthly_annex_rows.spreadsheet
                           .where(month: ..time.to_date.beginning_of_month)
                           .order(month: :desc)
                           .limit(1)
                           .pick(:portfolio_value)
    return annex_value.to_f if annex_value

    @investor.portfolio&.current_balance&.to_f
  end

  def portfolio_value_at_month_end(month)
    portfolio_value_at(effective_month_end(month))
  end

  def winbit_monthly_percent(month)
    start_date = month.beginning_of_month
    end_date = month.end_of_month

    results = DailyOperatingResult.where(date: start_date..end_date)
    return 0.0 if results.empty?

    factor = results.reduce(BigDecimal('1')) do |acc, r|
      acc * (BigDecimal('1') + (BigDecimal(r.percent.to_s) / 100))
    end

    ((factor - 1) * 100).round(2, :half_up).to_f
  end

  def compute_ytd_usd(annex_rows)
    annex_rows
      .reject { |r| r[:opening_snapshot] }
      .select { |r| r[:month].to_s.start_with?('2026-') && Date.parse("#{r[:month]}-01") <= @report_month }
      .sum { |r| r[:return_usd].to_f }
  end

  def serialize_row(month:, return_percent:, return_usd:, deposits:, withdrawals:, service_cost:,
                    portfolio_value:, opening_snapshot:, source:)
    month_key = month.is_a?(Date) ? month.strftime('%Y-%m') : month.to_s
    {
      month: month_key,
      label: MONTH_LABELS[month_key] || month_key,
      return_percent: opening_snapshot ? nil : return_percent,
      return_usd: opening_snapshot ? nil : return_usd,
      deposits: deposits,
      withdrawals: withdrawals,
      service_cost: service_cost,
      portfolio_value: portfolio_value,
      opening_snapshot: opening_snapshot,
      source: source,
    }
  end

  def bd(value)
    BigDecimal(value.to_s)
  end
end
