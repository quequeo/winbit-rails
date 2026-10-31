# frozen_string_literal: true

module EmailCampaigns
  # Builds template variables for monthly performance emails from MonthlyReportBuilder.
  #
  # Available variables:
  #   {{nombre}}       — investor name
  #   {{primer_nombre}} — first name only
  #   {{email}}        — investor email
  #   {{ganancia_usd}} — monthly RDO M $ (Argentine $X.XXX,XX) or "—" if missing
  #   {{ganancia_pct}} — monthly RDO M % (X,XX%) or "—" if missing
  #   {{mes}}          — report month YYYY-MM
  #   {{mes_nombre}} / {{mes_titulo}} — "octubre 2026" / "Octubre 2026"
  #   {{rentabilidad_mes}} — monthly return %, net of the service cost, number only (2,14)
  #   {{acumulado_anual}}  — year-to-date return %, net, number only (9,36)
  #   {{capital}}          — portfolio value at the report date (11.107,48)
  # The monthly figures are the same ones the PDF report shows.
  class MonthlyPerformanceVariables
    MISSING = '—'
    MONTH_NAMES = %w[_ enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

    class << self
      def call(investor:, report_month:)
        month_date = normalize_month(report_month)
        month_key = month_date.strftime('%Y-%m')
        report = MonthlyReportBuilder.new(investor: investor, report_month: month_date).build
        row = report[:month_row]
        summary = report[:summary]

        {
          'nombre' => investor.name.to_s,
          'primer_nombre' => investor.name.to_s.split.first.to_s,
          'email' => investor.email.to_s,
          'ganancia_usd' => format_currency_or_missing(row&.dig(:return_usd)),
          'ganancia_pct' => format_percent_or_missing(row&.dig(:return_percent)),
          'mes' => month_key,
          'mes_nombre' => "#{MONTH_NAMES[month_date.month]} #{month_date.year}",
          'mes_titulo' => "#{MONTH_NAMES[month_date.month].capitalize} #{month_date.year}",
          'ganancia_usd_raw' => row&.dig(:return_usd),
          'ganancia_pct_raw' => row&.dig(:return_percent),
          'rentabilidad_mes' => format_number_or_missing(row&.dig(:return_percent)),
          'acumulado_anual' => format_number_or_missing(summary[:accumulated_2026_percent]),
          'capital' => format_number_or_missing(summary[:portfolio_value_usd]),
        }
      end

      def available_variable_names
        %w[nombre primer_nombre email rentabilidad_mes acumulado_anual capital mes_nombre mes_titulo ganancia_usd ganancia_pct mes]
      end

      private

      def normalize_month(report_month)
        case report_month
        when Date, Time, DateTime, ActiveSupport::TimeWithZone
          report_month.to_date.beginning_of_month
        when String
          if report_month.match?(/\A\d{4}-\d{2}\z/)
            Date.strptime("#{report_month}-01", '%Y-%m-%d')
          else
            Date.parse(report_month).beginning_of_month
          end
        else
          report_month.to_date.beginning_of_month
        end
      end

      def format_number_or_missing(amount)
        return MISSING if amount.nil?

        format_currency(amount).delete_prefix('$')
      end

      def format_currency_or_missing(amount)
        return MISSING if amount.nil?

        format_currency(amount)
      end

      def format_percent_or_missing(amount)
        return MISSING if amount.nil?

        format_percent(amount)
      end

      def format_currency(amount)
        num = amount.to_f.round(2)
        formatted = format('%.2f', num)
        parts = formatted.split('.')
        parts[0].gsub!(/(\d)(?=(\d{3})+(?!\d))/, '\\1.')
        "$#{parts[0]},#{parts[1]}"
      end

      def format_percent(amount)
        num = amount.to_f.round(2)
        formatted = format('%.2f', num)
        parts = formatted.split('.')
        parts[0].gsub!(/(\d)(?=(\d{3})+(?!\d))/, '\\1.')
        "#{parts[0]},#{parts[1]}%"
      end
    end
  end
end
