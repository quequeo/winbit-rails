# frozen_string_literal: true

module EmailCampaigns
  # Builds template variables for monthly performance emails from MonthlyReportBuilder.
  #
  # Available variables:
  #   {{nombre}}       — investor name
  #   {{email}}        — investor email
  #   {{ganancia_usd}} — monthly RDO M $ (Argentine $X.XXX,XX) or "—" if missing
  #   {{ganancia_pct}} — monthly RDO M % (X,XX%) or "—" if missing
  #   {{mes}}          — report month YYYY-MM
  class MonthlyPerformanceVariables
    MISSING = '—'

    class << self
      def call(investor:, report_month:)
        month_date = normalize_month(report_month)
        month_key = month_date.strftime('%Y-%m')
        report = MonthlyReportBuilder.new(investor: investor, report_month: month_date).build
        row = find_month_row(report, month_key)

        {
          'nombre' => investor.name.to_s,
          'email' => investor.email.to_s,
          'ganancia_usd' => format_currency_or_missing(row&.dig(:return_usd)),
          'ganancia_pct' => format_percent_or_missing(row&.dig(:return_percent)),
          'mes' => month_key,
          'ganancia_usd_raw' => row&.dig(:return_usd),
          'ganancia_pct_raw' => row&.dig(:return_percent),
        }
      end

      def available_variable_names
        %w[nombre email ganancia_usd ganancia_pct mes]
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

      def find_month_row(report, month_key)
        Array(report[:annex_rows]).find do |r|
          r[:month] == month_key && !r[:opening_snapshot] && !r[:entry_row]
        end
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
