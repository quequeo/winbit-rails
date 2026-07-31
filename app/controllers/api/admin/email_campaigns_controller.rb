# frozen_string_literal: true

module Api
  module Admin
    class EmailCampaignsController < BaseController
      # GET /api/admin/email_campaigns/preview
      def preview
        month = parse_month_param
        return if performed?

        result = EmailCampaigns::Preview.call(
          month: month.strftime('%Y-%m'),
          subject: params[:subject],
          body: params[:body],
          investor_id: params[:investor_id]
        )

        render json: {
          data: {
            month: result.month,
            audienceCount: result.audience_count,
            variables: result.variables,
            recipients: result.recipients.map { |r| serialize_recipient(r) },
            sampleSubject: result.sample_subject,
            sampleBodyHtml: result.sample_body_html,
            sampleInvestor: result.sample_investor,
          }
        }
      end

      # POST /api/admin/email_campaigns/send_one
      def send_one
        month = parse_month_param
        return if performed?

        subject, body = require_template_params
        return if performed?

        investor = find_investor_by_id(id: params.require(:investor_id))
        return if performed?
        return unless investor

        result = EmailCampaigns::Send.call(
          month: month.strftime('%Y-%m'),
          subject: subject,
          body: body,
          investor_ids: [investor.id],
          force: true
        )

        render json: { data: serialize_send_result(result) }
      end

      # POST /api/admin/email_campaigns/send_mass
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

        result = EmailCampaigns::Send.call(
          month: month.strftime('%Y-%m'),
          subject: subject,
          body: body,
          force: true
        )

        render json: { data: serialize_send_result(result) }
      end

      private

      def parse_month_param
        raw = params[:month].presence
        unless raw&.match?(/\A\d{4}-\d{2}\z/)
          render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
          return nil
        end

        Date.strptime("#{raw}-01", '%Y-%m-%d')
      rescue ArgumentError
        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
        nil
      end

      def require_template_params
        subject = params[:subject].to_s
        body = params[:body].to_s

        if subject.blank?
          render_error('El asunto es obligatorio', status: :unprocessable_content)
          return [nil, nil]
        end

        if body.blank?
          render_error('El cuerpo del email es obligatorio', status: :unprocessable_content)
          return [nil, nil]
        end

        [subject, body]
      end

      def serialize_recipient(row)
        {
          id: row[:id],
          name: row[:name],
          email: row[:email],
          gananciaUsd: row[:ganancia_usd],
          gananciaPct: row[:ganancia_pct],
          variables: row[:variables],
          error: row[:error],
        }.compact
      end

      def serialize_send_result(result)
        {
          queuedCount: result.queued.size,
          skippedCount: result.skipped.size,
          failureCount: result.failures.size,
          totalAudience: result.total_audience,
          queued: result.queued,
          skipped: result.skipped,
          failures: result.failures,
        }
      end
    end
  end
end
