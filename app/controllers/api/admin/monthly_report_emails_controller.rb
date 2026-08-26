# frozen_string_literal: true

module Api
  module Admin
    class MonthlyReportEmailsController < BaseController
      # GET /api/admin/monthly_report_emails/preview
      def preview
        month = parse_month_param
        return if performed?

        result = InvestorMonthlyReportEmails::Preview.call(
          month: month,
          subject: params[:subject],
          body: params[:body],
          investor_id: params[:investor_id]
        )

        render json: { data: serialize_preview(result) }
      end

      # POST /api/admin/monthly_report_emails/send_one
      def send_one
        month = parse_month_param
        return if performed?

        subject, body = require_template_params
        return if performed?

        investor = find_investor_by_id(id: params.require(:investor_id))
        return if performed?
        return unless investor

        audience = InvestorMonthlyReportEmails::Audience.call(month: month, investor_id: investor.id)
        row = audience.rows.first
        unless row&.eligible
          render_error(
            InvestorMonthlyReportEmails::Audience.message_for(row&.skip_reason),
            status: :unprocessable_content
          )
          return
        end

        result = InvestorMonthlyReportEmails::Send.call(
          month: month,
          subject: subject,
          body: body,
          investor_ids: [ investor.id ]
        )

        render json: { data: serialize_send_result(result) }
      end

      # POST /api/admin/monthly_report_emails/send_mass
      def send_mass
        month = parse_month_param
        return if performed?

        subject, body = require_template_params
        return if performed?

        unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
          render_error(
            'Debés confirmar el envío masivo (confirm=true)',
            status: :unprocessable_content
          )
          return
        end

        audience = InvestorMonthlyReportEmails::Audience.call(month: month)
        if audience.eligible.empty?
          render_error('No hay destinatarios elegibles para este mes', status: :unprocessable_content)
          return
        end

        result = InvestorMonthlyReportEmails::Send.call(
          month: month,
          subject: subject,
          body: body
        )

        render json: { data: serialize_send_result(result) }
      end

      private

      def parse_month_param
        raw = params[:month].presence
        parsed = InvestorMonthlyReportPdfs::Month.parse(raw)
        return parsed if parsed

        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
        nil
      end

      def require_template_params
        subject = params[:subject].to_s
        body = params[:body].to_s

        if subject.blank?
          render_error('El asunto es obligatorio', status: :unprocessable_content)
          return [ nil, nil ]
        end

        if body.blank?
          render_error('El cuerpo del email es obligatorio', status: :unprocessable_content)
          return [ nil, nil ]
        end

        [ subject, body ]
      end

      def serialize_preview(result)
        {
          month: result.month,
          audienceCount: result.audience_count,
          variables: result.variables,
          recipients: result.recipients.map { |row| serialize_recipient(row) },
          skipped: result.skipped.map { |row| serialize_skipped(row) },
          sampleSubject: result.sample_subject,
          sampleBodyHtml: result.sample_body_html,
          sampleInvestor: result.sample_investor
        }
      end

      def serialize_recipient(row)
        {
          id: row[:id],
          name: row[:name],
          email: row[:email],
          hasPdf: row[:has_pdf],
          balance: row[:balance],
          pdfFilename: row[:pdf_filename],
          gananciaUsd: row[:ganancia_usd],
          gananciaPct: row[:ganancia_pct]
        }
      end

      def serialize_skipped(row)
        {
          id: row[:id],
          name: row[:name],
          email: row[:email],
          hasPdf: row[:has_pdf],
          balance: row[:balance],
          skipReason: row[:skip_reason],
          skipMessage: row[:skip_message]
        }
      end

      def serialize_send_result(result)
        {
          queuedCount: result.queued.size,
          skippedCount: result.skipped.size,
          failureCount: result.failures.size,
          totalAudience: result.total_audience,
          queued: result.queued,
          skipped: result.skipped,
          failures: result.failures
        }
      end
    end
  end
end
