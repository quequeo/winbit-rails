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
        *check_accumulated_year,
        *check_last_annex_value,
      ]
    end

    private

    def summary
      @report[:summary]
    end

    def current_month_row
      key = @report_month.strftime('%Y-%m')
      @report[:annex_rows].find { |r| r[:month] == key && !r[:opening_snapshot] && !r[:entry_row] }
    end

    # Trades come from the investor's own OPERATING_RESULT PortfolioHistory
    # rows (see MonthlyOperationsReport), so this should always tie out
    # exactly to the annex row's gross monthly return - any gap means a
    # trade is missing/duplicated or a daily result wasn't attributed.
    def check_operations_sum
      row = current_month_row
      return [] unless row && row[:return_usd]

      ops_total = @operations.trades.sum(&:result_usd)
      expected = row[:return_usd].to_f
      return [] if (ops_total - expected).abs <= 0.5

      ["La suma de las operaciones del mes da #{money(ops_total)} y el rendimiento mensual informado es #{money(expected)}."]
    end

    def check_missing_direction
      @operations.trades.select { |t| t.direction.blank? }.map do |t|
        "La operación del #{t.date.strftime('%d/%m')} (#{t.asset}) no tiene dirección (LONG/SHORT)."
      end
    end

    # accumulated_2026_usd comes from the live TWR-compounding field (not
    # summed from annex rows - see MonthlyReportBuilder#accumulated_net_as_of),
    # so it can legitimately diverge from a plain sum of the year's rows for
    # investors with large interim withdrawals (same reason the annex sum
    # isn't used directly - see the Fabrizio Bruno / Crocci case spec). The
    # tolerance is scaled, not fixed, to avoid false alarms for those cases
    # while still catching a real break (the bug this whole fix addresses
    # showed up as an 18%+ gap).
    def check_accumulated_year
      rows = year_to_date_rows
      return [] if rows.empty?

      expected = rows.sum { |r| r[:return_usd].to_f - r[:service_cost].to_f }
      actual = summary[:accumulated_2026_usd].to_f
      tolerance = [5.0, actual.abs * 0.1].max
      return [] if (expected - actual).abs <= tolerance

      ["El acumulado #{@report_month.year} informado es #{money(actual)}, pero la suma neta de las filas del año da #{money(expected)}."]
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
