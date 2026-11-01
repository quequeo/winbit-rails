# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Sanity-check warnings for a monthly report, shown in the admin before
  # downloading the PDF (never blocking) - ports validar() from
  # docs/reporte_mensual_kit/generar_reportes.py, adapted to the data Rails
  # actually has (MonthlyReportBuilder/MonthlyOperationsReport), not the
  # Excel export the Python script used to parse back.
  #
  # Two of the Python checks have no Rails equivalent and are dropped:
  # cross-checking positive/negative/BE counts against a manually-typed
  # Excel summary cell (there's only one source of truth here, computed
  # once by MonthlyOperationsReport - nothing to cross-check against), and
  # the "acumulado desde el ingreso" reconciliation (would need the gross
  # figure behind accumulated_since_entry_usd, which MonthlyReportBuilder
  # doesn't expose - only the already-fee-netted result).
  class Validate
    def self.call(investor:, report_month:)
      new(investor:, report_month:).call
    end

    def initialize(investor:, report_month:)
      @investor = investor
      @report_month = report_month.is_a?(String) ? Date.strptime("#{report_month}-01", '%Y-%m-%d') : report_month.to_date.beginning_of_month
      @report = MonthlyReportBuilder.new(investor: @investor, report_month: @report_month).build
      @operations = MonthlyOperationsReport.call(investor: @investor, month: @report_month)
    end

    def call
      [
        *check_operations_sum,
        *check_missing_direction,
        *check_rows,
        *check_accumulated_year,
        *check_last_annex_value,
        *check_negative_zero,
      ]
    end

    private

    def summary
      @report[:summary]
    end

    def current_month_row
      @report[:month_row]
    end

    # Trades come from the investor's own OPERATING_RESULT PortfolioHistory
    # rows (see MonthlyOperationsReport), so this should always tie out
    # exactly to the annex row's monthly return before the service cost (the
    # row itself is net) - any gap means a trade is missing/duplicated or a
    # daily result wasn't attributed.
    def check_operations_sum
      row = current_month_row
      return [] unless row && row[:return_usd]

      ops_total = @operations.trades.sum(&:result_usd)
      expected = row[:return_usd].to_f + row[:service_cost].to_f
      return [] if (ops_total - expected).abs <= 0.5

      ["La suma de las operaciones del mes da #{money(ops_total)} y el rendimiento mensual antes del costo del servicio es #{money(expected)}."]
    end

    def check_missing_direction
      @operations.trades.select { |t| t.direction.blank? }.map do |t|
        "La operación del #{t.date.strftime('%d/%m')} (#{t.asset}) no tiene dirección (LONG/SHORT)."
      end
    end

    # Every month's row has to close with its own values: previous value +
    # result + deposits - withdrawals = value, and its percent = result over
    # the previous value (0,05 pp). An investor's first month has no previous
    # value, so its percent is left out.
    def check_rows
      rows = @report[:annex_rows]
      year_to_date_rows.filter_map do |row|
        index = rows.index(row)
        previous = index&.positive? ? rows[index - 1] : nil
        next if previous.nil? || previous[:portfolio_value].nil? || row[:return_usd].nil?

        expected_usd = row[:portfolio_value].to_f - previous[:portfolio_value].to_f - row[:deposits].to_f + row[:withdrawals].to_f
        if (expected_usd - row[:return_usd].to_f).abs > 0.5
          next "#{row[:label]}: el resultado informado es #{money(row[:return_usd])} y según los valores de la tabla es #{money(expected_usd)}."
        end

        next unless previous[:portfolio_value].to_f.positive?

        expected_percent = row[:return_usd].to_f / previous[:portfolio_value].to_f * 100
        next if (expected_percent - row[:return_percent].to_f).abs <= 0.05

        "#{row[:label]}: el rendimiento informado es #{format('%.2f', row[:return_percent].to_f)}% y según los valores es #{format('%.2f', expected_percent)}%."
      end
    end

    # The year's accumulated result comes from the strategy figures, net of
    # the service cost; it has to match what the table's own values add up to.
    def check_accumulated_year
      rows = year_to_date_rows
      return [] if rows.empty?

      expected = rows.sum { |r| r[:return_usd].to_f }
      actual = summary[:accumulated_2026_usd].to_f
      return [] if (expected - actual).abs <= 2

      ["El acumulado #{@report_month.year} informado es #{money(actual)}, pero los valores de la tabla del año dan #{money(expected)}."]
    end

    # Nothing in the PDF may read "-0" (or "-0,0%").
    def check_negative_zero
      cells = collect_strings(DocumentData.call(investor: @investor, report_month: @report_month))
      bad = cells.select { |text| text.match?(/(?<![\d,.])-0(?:,0+)?(?![\d,])/) }
      return [] if bad.empty?

      ["Hay celdas que muestran \"-0\": #{bad.uniq.first(3).join(', ')}."]
    end

    def collect_strings(value)
      case value
      when String then [ value ]
      when Hash then value.except(:chart_svg).values.flat_map { |v| collect_strings(v) }
      when Array then value.flat_map { |v| collect_strings(v) }
      else []
      end
    end

    # The last year-to-date annex row and the summary's portfolio value are
    # built from the same underlying balance for the same report_month (see
    # MonthlyReportBuilder#portfolio_value_for_summary/#build_platform_row) -
    # a mismatch here means the two sides drifted, e.g. a stale spreadsheet
    # import row.
    def check_last_annex_value
      rows = year_to_date_rows
      return [] if rows.empty?

      last_value = rows.last[:portfolio_value].to_f
      current_value = summary[:portfolio_value_usd].to_f
      return [] if (last_value - current_value).abs <= 1

      ["El último valor del historial (#{money(last_value)}) no coincide con el valor actual del portafolio (#{money(current_value)})."]
    end

    # Same scope as DocumentData#year_to_date_rows: rows within the report's
    # calendar year, up to and including the report month.
    def year_to_date_rows
      key_year = @report_month.year.to_s
      @report[:annex_rows].select do |r|
        !r[:opening_snapshot] && !r[:entry_row] &&
          r[:month].to_s.start_with?(key_year) &&
          Date.parse("#{r[:month]}-01") <= @report_month
      end
    end

    def money(value)
      "USD #{format('%.2f', value)}"
    end
  end
end
