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
    opening_row = annex_rows.find { |r| r[:entry_row] || r[:opening_snapshot] }
    dashboard = InvestorPortfolioDashboardPayload.build(investor: @investor) || {}

    {
      investor: {
        id: @investor.id,
        name: @investor.name,
        email: @investor.email,
      },
      report_month: @report_month.strftime('%Y-%m'),
      summary: build_summary(dashboard, opening_row:),
      annex_rows: annex_rows,
    }
  end

  private

  def build_summary(dashboard, opening_row:)
    {
      portfolio_value_usd: portfolio_value_for_summary,
      winbit_monthly_return_percent: winbit_monthly_percent(@report_month),
      # Ingresos netos (depositos - retiros), igual que Portfolio#total_invested.
      net_contributed_usd: dashboard[:totalInvested],
      # Depositos - retiros de por vida (a diferencia de net_contributed_usd,
      # este sí descuenta lo retirado - ver AGENTS/CST_FEE_LOGIC para por qué
      # ambos existen: total_invested nunca baja con retiros en el resto de
      # la app, pero para este reporte también hace falta el neto real).
      net_contributed_after_withdrawals_usd: lifetime_net_contributed,
      # Lifetime figures mirror the investor panel (strategy_return_all_*).
      accumulated_since_entry_usd: dashboard[:strategyReturnAllUSD],
      accumulated_since_entry_percent: dashboard[:strategyReturnAllPercent],
      # TWR-based, from the investor panel (strategy_return_ytd_*) - robust to
      # large interim withdrawals, unlike a plain (end - Jan1 balance) / Jan1
      # balance calculation, which understates return for anyone who pulled
      # out much of their opening balance mid-year.
      accumulated_2026_usd: dashboard[:strategyReturnYtdUSD],
      accumulated_2026_percent: dashboard[:strategyReturnYtdPercent],
      # Snapshot used as the YTD chart/table's starting point (see DocumentData).
      year_opening_date: Date.new(@report_month.year, 1, 1).strftime('%Y-%m-%d'),
      year_opening_balance_usd: opening_row&.dig(:portfolio_value),
    }
  end

  def lifetime_net_contributed
    flows = aggregate_flows(Time.zone.local(2000, 1, 1), effective_month_end(@report_month))
    (bd(flows[:deposits]) - bd(flows[:withdrawals])).round(2, :half_up).to_f
  end

  def portfolio_value_for_summary
    portfolio = @investor.portfolio
    return portfolio_value_at_month_end(@report_month) unless portfolio

    if @report_month == Date.current.beginning_of_month
      portfolio.current_balance.to_f
    else
      portfolio_value_at_month_end(@report_month)
    end
  end

  def build_annex_rows
    rows = spreadsheet_rows
    migrated_from_spreadsheet = rows.present?
    # Investors with no spreadsheet history (joined after the migration cutoff,
    # entirely native to the platform) have no opening_snapshot/entry_row -
    # synthesize their entry at 0, same as an imported investor's genesis row
    # would be, so the Anexo table has a starting point to show/label.
    rows << synthetic_entry_row if rows.empty?

    platform_start = SPREADSHEET_LAST_MONTH.next_month
    month = platform_start

    while month <= @report_month
      rows << build_platform_row(month, previous_row: rows.last, migrated_from_spreadsheet:)
      month = month.next_month
    end

    rows
  end

  def synthetic_entry_row
    serialize_row(
      month: SPREADSHEET_LAST_MONTH.strftime('%Y-%m'),
      return_percent: nil,
      return_usd: nil,
      deposits: 0,
      withdrawals: 0,
      service_cost: 0,
      portfolio_value: 0,
      opening_snapshot: false,
      entry_row: true,
      source: 'platform',
    )
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
        entry_row: row.entry_row,
        source: row.source,
      )
    end
  end

  def build_platform_row(month, previous_row:, migrated_from_spreadsheet:)
    month_start = month.beginning_of_month
    month_end = effective_month_end(month)
    flow_start = flow_start_for(month, month_start, migrated_from_spreadsheet:)

    flows = aggregate_flows(flow_start, month_end)
    end_value = portfolio_value_at(month_end)
    previous_close = previous_row&.dig(:portfolio_value).to_f

    net_return_usd = (
      bd(end_value) - bd(previous_close) - bd(flows[:deposits]) + bd(flows[:withdrawals])
    ).round(2, :half_up)

    # RDO M $ / % = gross Winbit return; CST is shown separately in its own column.
    gross_return_usd = (net_return_usd + bd(flows[:service_cost])).round(2, :half_up)

    return_percent = if previous_close.positive?
                       ((gross_return_usd / bd(previous_close)) * 100).round(2, :half_up)
    else
                       BigDecimal('0')
    end

    serialize_row(
      month: month,
      return_percent: return_percent.to_f,
      return_usd: gross_return_usd.to_f,
      deposits: flows[:deposits],
      withdrawals: flows[:withdrawals],
      service_cost: flows[:service_cost],
      portfolio_value: end_value,
      opening_snapshot: false,
      entry_row: false,
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

  # The May 2026 genesis migration dumped a lump-sum "catch-up" deposit/result
  # for every *migrated* investor dated May 1-3; excluding that window keeps
  # it from being double-counted as real May activity. Investors with no
  # spreadsheet history never had a genesis lump to exclude - for them this
  # window is just their first few real days on the platform, so the normal
  # month start applies.
  def flow_start_for(month, month_start, migrated_from_spreadsheet:)
    return POST_GENESIS_FLOW_START if migrated_from_spreadsheet && month == Date.new(2026, 5, 1)

    month_start.beginning_of_day
  end

  # Current month: include all of today (through end_of_day), not Time.current.
  # Daily operativa is stamped at 17:00 (movement_time); generating the report
  # earlier in the day would otherwise exclude today's OPERATING_RESULT.
  def effective_month_end(month)
    if month == Date.current.beginning_of_month
      Date.current.end_of_day
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

  def serialize_row(month:, return_percent:, return_usd:, deposits:, withdrawals:, service_cost:,
                    portfolio_value:, opening_snapshot:, entry_row:, source:)
    month_key = month.is_a?(Date) ? month.strftime('%Y-%m') : month.to_s
    {
      month: month_key,
      label: row_label(month_key, opening_snapshot:, entry_row:),
      return_percent: opening_snapshot || entry_row ? nil : return_percent,
      return_usd: opening_snapshot || entry_row ? nil : return_usd,
      deposits: deposits,
      withdrawals: withdrawals,
      service_cost: service_cost,
      portfolio_value: portfolio_value,
      opening_snapshot: opening_snapshot,
      entry_row: entry_row,
      source: source,
    }
  end

  def row_label(month_key, opening_snapshot:, entry_row:)
    return 'INGRESO' if entry_row
    return MONTH_LABELS[month_key] || month_key if opening_snapshot && month_key == '2025-12'

    MONTH_LABELS[month_key] || month_key
  end

  def bd(value)
    BigDecimal(value.to_s)
  end
end
