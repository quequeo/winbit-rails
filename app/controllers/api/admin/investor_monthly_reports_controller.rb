# frozen_string_literal: true

module Api
  module Admin
    class InvestorMonthlyReportsController < BaseController
      before_action :set_investor

      def show
        month = parse_month_param
        return if performed?

        builder = MonthlyReportBuilder.new(investor: @investor, report_month: month)
        render json: { data: AdminInvestorMonthlyReportSerializer.new(builder.build).as_json }
      end

      private

      def set_investor
        @investor = find_investor_by_id(id: params[:id], includes: [:portfolio, :investor_monthly_annex_rows])
      end

      def parse_month_param
        raw = params[:month].presence || Date.current.strftime('%Y-%m')
        unless raw.match?(/\A\d{4}-\d{2}\z/)
          render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
          return nil
        end

        Date.strptime("#{raw}-01", '%Y-%m-%d')
      rescue ArgumentError
        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
        nil
      end
    end
  end
end
