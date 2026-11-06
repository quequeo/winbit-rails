# frozen_string_literal: true

module Api
  module Admin
    class EmailCampaignsController < BaseController
      RECORD_KIND = 'CAMPAIGN'

      # GET /api/admin/email_campaigns/preview
      def preview
        month = parse_month_param
        return if performed?

        result = EmailCampaigns::Preview.call(
          month: month.strftime('%Y-%m'),
          subject: params[:subject],
          body: params[:body],
          investor_id: params[:investor_id],
          sample_investor_id: params[:sample_investor_id]
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
      # Optional multipart field: attachment (PDF/XLSX ≤10MB)
      # With test_email, sends that investor's email to that address instead and logs nothing.
      def send_one
        month = parse_month_param
        return if performed?

        subject, body = require_template_params
        return if performed?

        test_email = params[:test_email].to_s.strip.presence
        if test_email && !test_email.match?(URI::MailTo::EMAIL_REGEXP)
          render_error('El correo de prueba no es válido', status: :unprocessable_content)
          return
        end

        investor = find_investor_by_id(id: params.require(:investor_id))
        return if performed?
        return unless investor

        attachments_by_id = {}
        upload = params[:attachment]
        if upload.present?
          begin
            attachments_by_id[investor.id.to_s] = EmailCampaigns::Attachment.from_upload(upload)
          rescue ArgumentError => e
            render_error(e.message, status: :unprocessable_content)
            return
          end
        end

        result = EmailCampaigns::Send.call(
          month: month.strftime('%Y-%m'),
          subject: subject,
          body: body,
          investor_ids: [investor.id],
          force: true,
          attachments_by_investor_id: attachments_by_id,
          to_email: test_email,
          app_button: app_button_param,
          record_as: test_email ? nil : RECORD_KIND
        )

        render json: { data: serialize_send_result(result) }
      end

      # POST /api/admin/email_campaigns/send_mass
      # Optional multipart: attachments[investor_id] = file (PDF/XLSX ≤10MB each)
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

        investor_ids = parse_investor_ids
        return if performed?

        attachments_by_id = parse_mass_attachments
        return if performed?

        result = EmailCampaigns::Send.call(
          month: month.strftime('%Y-%m'),
          subject: subject,
          body: body,
          investor_ids: investor_ids,
          force: true,
          attachments_by_investor_id: attachments_by_id,
          app_button: app_button_param,
          record_as: RECORD_KIND
        )

        render json: { data: serialize_send_result(result) }
      end

      # GET /api/admin/email_campaigns/schedules
      def schedules
        records = ScheduledCampaignEmail.includes(:scheduled_by).recent_first.limit(20)
        render json: { data: records.map { |record| serialize_schedule(record) } }
      end

      # POST /api/admin/email_campaigns/schedule
      def schedule
        month = parse_month_param
        return if performed?

        subject, body = require_template_params
        return if performed?

        investor_ids = parse_investor_ids
        return if performed?

        scheduled_for = parse_scheduled_for
        return if performed?

        record = ScheduledCampaignEmail.create!(
          month: month.strftime('%Y-%m'),
          subject: subject,
          body: body,
          scheduled_for: scheduled_for,
          investor_ids: investor_ids,
          app_button: app_button_param,
          scheduled_by: current_user
        )

        render json: { data: serialize_schedule(record) }, status: :created
      end

      # POST /api/admin/email_campaigns/schedules/:id/cancel
      def cancel_schedule
        record = ScheduledCampaignEmail.find_by(id: params[:id])
        return render_error('Envío programado no encontrado', status: :not_found) unless record

        record.with_lock do
          unless record.status == 'SCHEDULED'
            render_error('Solo se puede cancelar un envío que todavía no salió', status: :unprocessable_content)
            next
          end

          record.update!(status: 'CANCELED')
        end
        return if performed?

        render json: { data: serialize_schedule(record) }
      end

      private

      def app_button_param
        ActiveModel::Type::Boolean.new.cast(params[:app_button]) == true
      end

      # nil means every active investor. A selection must name active investors:
      # an empty one is an error, so it can never end up going to everyone.
      def parse_investor_ids
        return nil unless params[:audience] == 'selected' || params.key?(:investor_ids)

        ids = Array(params[:investor_ids]).map(&:to_s).compact_blank.uniq
        if ids.empty?
          render_error('Elegí al menos un inversor', status: :unprocessable_content)
          return nil
        end

        active_ids = Investor.where(id: ids, status: 'ACTIVE').pluck(:id).map(&:to_s)
        return ids if active_ids.size == ids.size

        render_error('Hay inversores elegidos que no están activos', status: :unprocessable_content)
        nil
      end

      def parse_scheduled_for
        scheduled_for = Time.zone.parse(params[:scheduled_for].to_s)
        if scheduled_for.nil?
          render_error('Fecha y hora de envío inválidas', status: :unprocessable_content)
          return
        end
        unless scheduled_for.future?
          render_error('La fecha y hora de envío tiene que ser futura', status: :unprocessable_content)
          return
        end

        scheduled_for
      rescue ArgumentError
        render_error('Fecha y hora de envío inválidas', status: :unprocessable_content)
        nil
      end

      def serialize_schedule(record)
        {
          id: record.id,
          month: record.month,
          subject: record.subject,
          scheduledFor: record.scheduled_for&.iso8601,
          status: record.status,
          audienceCount: record.investor_ids&.size,
          appButton: record.app_button,
          sentAt: record.sent_at&.iso8601,
          queuedCount: record.queued_count,
          skippedCount: record.skipped_count,
          failureCount: record.failure_count,
          scheduledBy: record.scheduled_by&.name,
        }
      end

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

      def parse_mass_attachments
        raw = params[:attachments]
        return {} if raw.blank?

        unless raw.respond_to?(:each)
          render_error('attachments debe ser un mapa investor_id → archivo', status: :unprocessable_content)
          return {}
        end

        result = {}
        raw.each do |investor_id, upload|
          next if upload.blank?

          begin
            result[investor_id.to_s] = EmailCampaigns::Attachment.from_upload(upload)
          rescue ArgumentError => e
            render_error("Adjunto inversor #{investor_id}: #{e.message}", status: :unprocessable_content)
            return {}
          end
        end
        result
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
