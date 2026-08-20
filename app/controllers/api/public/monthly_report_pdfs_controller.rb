# frozen_string_literal: true

module Api
  module Public
    class MonthlyReportPdfsController < BaseController
      def show
        email = CGI.unescape(params[:email].to_s)

        investor = find_investor_by_email(email: email, message: 'Investor not found')
        return unless investor
        return unless require_active_investor!(investor, message: 'Investor is not active')

        month = parse_month_param
        return if performed?

        report = InvestorMonthlyReportPdf.find_by(investor_id: investor.id, month: month)
        unless report
          render json: { error: 'Reporte no encontrado' }, status: :not_found
          return
        end

        send_data report.pdf_data,
                  type: 'application/pdf',
                  disposition: 'attachment',
                  filename: report.download_filename
      end

      private

      def parse_month_param
        raw = params[:month].presence || InvestorMonthlyReportPdf.last_closed_month
        parsed = InvestorMonthlyReportPdfs::Month.parse(raw)
        return parsed if parsed

        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
        nil
      end
    end
  end
end
