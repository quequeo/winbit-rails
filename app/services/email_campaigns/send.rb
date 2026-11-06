# frozen_string_literal: true

module EmailCampaigns
  # Sends personalized campaign emails. Admin-initiated: always force-bypasses NotificationGate.
  class Send
    Result = Struct.new(:queued, :skipped, :failures, :total_audience, keyword_init: true)
    Failure = Struct.new(:investor_id, :email, :error, keyword_init: true)

    def self.call(month:, subject:, body:, investor_ids: nil, force: true, attachments_by_investor_id: {}, to_email: nil,
                  record_as: nil, app_button: true)
      new(
        month: month,
        subject: subject,
        body: body,
        investor_ids: investor_ids,
        force: force,
        attachments_by_investor_id: attachments_by_investor_id,
        to_email: to_email,
        record_as: record_as,
        app_button: app_button
      ).call
    end

    def initialize(month:, subject:, body:, investor_ids: nil, force: true, attachments_by_investor_id: {}, to_email: nil,
                   record_as: nil, app_button: true)
      @month = month
      @subject = subject
      @body = body
      # nil means every active investor; an empty list means nobody, never everyone.
      @investor_ids = investor_ids.nil? ? nil : Array(investor_ids)
      @force = force
      # Investor ids are UUIDs (strings). Never use to_i — "57d1ee81…".to_i => 57.
      @attachments_by_investor_id = (attachments_by_investor_id || {}).transform_keys { |k| k.to_s }
      # Test send: every message goes to this address instead of the investor's.
      @to_email = to_email.presence
      # OutgoingEmail kind under which each delivered message is logged; nil logs nothing.
      @record_as = record_as
      @app_button = app_button
    end

    def call
      queued = []
      skipped = []
      failures = []

      investors.find_each do |investor|
        if investor.email.blank?
          skipped << { investor_id: investor.id, reason: 'blank_email' }
          next
        end

        vars = MonthlyPerformanceVariables.call(investor: investor, report_month: @month)
        rendered_subject = TemplateRenderer.render_plain(@subject, vars)
        rendered_body_html = TemplateRenderer.render_html(@body, vars)
        attachment = @attachments_by_investor_id[investor.id.to_s]

        message = InvestorMailer.campaign_message(
          investor,
          subject: rendered_subject,
          body_html: rendered_body_html,
          force: @force,
          attachment: attachment,
          to: @to_email,
          app_button: @app_button
        )

        # Attachments carry binary payloads that Active Job may not serialize safely.
        # Logged emails and test sends have to really go out, not just be queued.
        if attachment || @record_as.present? || @to_email
          message.deliver_now
        else
          message.deliver_later
        end

        queued << {
          investor_id: investor.id,
          email: @to_email || investor.email,
          attached: !attachment.nil?,
        }
        record_sent(investor, message.message)
      rescue StandardError => e
        Rails.logger.error(
          "[EmailCampaigns::Send] investor=#{investor.id} email=#{investor.email}: #{e.class}: #{e.message}"
        )
        failures << Failure.new(investor_id: investor.id, email: investor.email, error: e.message)
      end

      Result.new(
        queued: queued,
        skipped: skipped,
        failures: failures.map { |f| { investor_id: f.investor_id, email: f.email, error: f.error } },
        total_audience: investors.count
      )
    end

    private

    # The email already left: a logging problem must not report it as failed.
    def record_sent(investor, mail)
      return if @record_as.blank?

      OutgoingEmail.create!(
        investor: investor,
        kind: @record_as,
        status: 'SENT',
        sent_at: Time.current,
        to_email: investor.email,
        subject: mail.subject,
        body_html: (mail.html_part || mail).body.decoded,
        body_text: mail.text_part&.body&.decoded
      )
    rescue StandardError => e
      Rails.logger.error("[EmailCampaigns::Send] no se registró el envío a investor=#{investor.id}: #{e.message}")
    end

    def investors
      scope = Investor.where(status: 'ACTIVE').where.not(email: [nil, ''])
      scope = scope.where(id: @investor_ids) unless @investor_ids.nil?
      scope.order(:id)
    end
  end
end
