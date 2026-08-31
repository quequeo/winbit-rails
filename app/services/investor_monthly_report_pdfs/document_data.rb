# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Builds the fully-formatted data hash consumed by the monthly report PDF
  # view (app/views/investor_monthly_report_pdfs/document.html.erb).
  #
  # All numbers are already formatted here (Argentine thousands/decimals,
  # +/- signs, CSS sign classes) so the ERB template has no business logic.
  #
  # Reuses MonthlyReportBuilder (same source of truth as the on-screen
  # report and the email variables) plus MonthlyOperationsReport for the
  # "Operaciones del mes" page - this investor's own daily $ result paired
  # with that day's trade (see MonthlyOperationsReport for how).
  class DocumentData
    MONTH_NAMES = {
      1 => 'Enero', 2 => 'Febrero', 3 => 'Marzo', 4 => 'Abril', 5 => 'Mayo', 6 => 'Junio',
      7 => 'Julio', 8 => 'Agosto', 9 => 'Septiembre', 10 => 'Octubre', 11 => 'Noviembre', 12 => 'Diciembre',
    }.freeze

    # The trades table (page 4+) has no fixed row count: a given month can
    # have anywhere from zero to dozens of trades. This is the empirically
    # validated max rows/page that fits safely under wkhtmltopdf, whether the
    # page carries the full header chrome (first ops page) or the closing
    # stats bar (last ops page).
    OPS_PAGE_LIMIT = 14

    def self.call(investor:, report_month:)
      new(investor:, report_month:).call
    end

    def initialize(investor:, report_month:)
      @investor = investor
      @report_month = report_month.is_a?(String) ? Date.strptime("#{report_month}-01", '%Y-%m-%d') : report_month.to_date.beginning_of_month
      @report = MonthlyReportBuilder.new(investor: investor, report_month: @report_month).build
    end

    def call
      summary = @report[:summary]

      {
        investor_name: @investor.name,
        month_label: "#{MONTH_NAMES[@report_month.month].upcase} #{@report_month.year}",
        month_label_full: "#{MONTH_NAMES[@report_month.month]} #{@report_month.year}",
        as_of_date: (@report_month.end_of_month <= Date.current ? @report_month.end_of_month : Date.current).strftime('%d/%m/%Y'),
        portfolio_value: amount(summary[:portfolio_value_usd]),
        net_contributed: amount(summary[:net_contributed_usd]),
        monthly: signed_pair(current_month_row&.dig(:return_percent), current_month_row&.dig(:return_usd)),
        ytd: signed_pair(summary[:accumulated_2026_percent], summary[:accumulated_2026_usd]),
        since_entry: signed_pair(summary[:accumulated_since_entry_percent], summary[:accumulated_since_entry_usd]),
        year_opening: {
          date: Date.parse(summary[:year_opening_date]).strftime('%d/%m/%Y'),
          value: amount(summary[:year_opening_balance_usd]),
        },
        evo_rows: evo_rows,
        evo_total: signed_pair(summary[:accumulated_2026_percent], summary[:accumulated_2026_usd]),
        chart_svg: ChartSvg.build(rows: evo_rows_for_chart, initial_value: summary[:year_opening_balance_usd].to_f),
        ops_pages: ops_pages,
      }
    end

    private

    def current_month_row
      key = @report_month.strftime('%Y-%m')
      @report[:annex_rows].find { |r| r[:month] == key && !r[:opening_snapshot] && !r[:entry_row] }
    end

    def evo_rows
      rows = year_to_date_rows
      rows.map.with_index do |r, i|
        {
          label: r[:label],
          portfolio_value: amount(r[:portfolio_value]),
          deposits: amount(r[:deposits]),
          withdrawals: amount(r[:withdrawals]),
          service_cost: amount(r[:service_cost]),
          return_percent: signed_percent(r[:return_percent]),
          return_percent_class: sign_class(r[:return_percent]),
          return_usd: signed_amount(r[:return_usd]),
          return_usd_class: sign_class(r[:return_usd]),
          last: i == rows.size - 1,
        }
      end
    end

    def evo_rows_for_chart
      year_to_date_rows
    end

    # Same scope as MonthlyReportBuilder's internal YTD calc: rows within the
    # report's calendar year, up to and including the report month.
    def year_to_date_rows
      key_year = @report_month.year.to_s
      @report[:annex_rows].select do |r|
        !r[:opening_snapshot] && !r[:entry_row] &&
          r[:month].to_s.start_with?(key_year) &&
          Date.parse("#{r[:month]}-01") <= @report_month
      end
    end

    def operations_report
      @operations_report ||= MonthlyOperationsReport.call(investor: @investor, month: @report_month)
    end

    def trade_row(trade)
      {
        date: trade.date.strftime('%d/%m'),
        asset: trade.asset,
        direction: trade.direction || '-',
        opened_at: trade.opened_at.presence || '-',
        closed_at: trade.closed_at.presence || '-',
        result_usd: signed_amount(trade.result_usd),
        result_percent: signed_percent(trade.result_percent),
        result_class: trade_result_class(trade.result_label),
        ratio: signed_ratio(trade.ratio),
      }
    end

    def ops_summary
      report = operations_report
      {
        count: report.count,
        positive: report.positive,
        negative: report.negative,
        break_even: report.break_even,
        net_result: signed_amount_with_unit(report.net_result_usd),
        net_result_class: sign_class(report.net_result_usd),
        monthly_return_percent: signed_percent(@report[:summary][:winbit_monthly_return_percent]),
      }
    end

    # Splits the (unbounded) trades list into fixed-size pages so the
    # "Operaciones del mes" section always fits the printed page, no matter
    # how many trades happened that month. Every page carries its own
    # sequential page number (continuing on from the fixed cover/resumen/
    # evolución pages); only the first page shows the asset chips, and only
    # the last page shows the closing footnote + stats bar.
    def ops_pages
      trade_rows = operations_report.trades.map { |trade| trade_row(trade) }
      chunks = trade_rows.each_slice(OPS_PAGE_LIMIT).to_a
      chunks = [[]] if chunks.empty?
      chips = operations_report.assets
      summary = ops_summary
      last_index = chunks.size - 1

      chunks.map.with_index do |page_trades, index|
        {
          page_number: format('%02d', 4 + index),
          first: index.zero?,
          last: index == last_index,
          trades: page_trades,
          assets: index.zero? ? chips : nil,
          ops_summary: index == last_index ? summary : nil,
        }
      end
    end

    def signed_pair(percent, usd)
      {
        percent: signed_percent(percent),
        usd: signed_amount_with_unit(usd),
        class: sign_class(percent),
      }
    end

    def sign_class(value)
      return '' if value.nil?

      value.to_f.positive? ? 'pos' : (value.to_f.negative? ? 'neg' : '')
    end

    # A trade the system calls break-even (BE+/BE-) shouldn't render red/green
    # just because this investor's proportional $ happened to round negative.
    def trade_result_class(result_label)
      case result_label
      when 'POSITIVO' then 'pos'
      when 'NEGATIVO' then 'neg'
      else ''
      end
    end

    def amount(value, decimals: 0)
      return '0' if value.nil?

      formatted = format("%.#{decimals}f", value.to_f.abs)
      whole, dec = formatted.split('.')
      whole = whole.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
      text = dec ? "#{whole},#{dec}" : whole
      value.to_f.negative? ? "-#{text}" : text
    end

    def signed_amount(value, decimals: 0)
      return '0' if value.nil?

      sign = value.to_f.positive? ? '+' : (value.to_f.negative? ? '-' : '')
      "#{sign}#{amount(value.to_f.abs, decimals: decimals)}"
    end

    def signed_amount_with_unit(value)
      "#{signed_amount(value)} USD"
    end

    def signed_percent(value, decimals: 1)
      return '0,0 %' if value.nil?

      sign = value.to_f.positive? ? '+' : (value.to_f.negative? ? '-' : '')
      "#{sign}#{amount(value.to_f.abs, decimals: decimals)} %"
    end

    def signed_ratio(value)
      return '—' if value.nil?

      sign = value.to_f.positive? ? '+' : (value.to_f.negative? ? '-' : '')
      "#{sign}#{format('%.2f', value.to_f.abs).tr('.', ',')} R"
    end
  end
end
