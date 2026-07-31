# frozen_string_literal: true

module EmailCampaigns
  # Sends personalized campaign emails. Admin-initiated: always force-bypasses NotificationGate.
  class Send
    Result = Struct.new(:queued, :skipped, :failures, :total_audience, keyword_init: true)
    Failure = Struct.new(:investor_id, :email, :error, keyword_init: true)

    def self.call(month:, subject:, body:, investor_ids: nil, force: true, attachments_by_investor_id: {})
      new(
        month: month,
        subject: subject,
        body: body,
        investor_ids: investor_ids,
        force: force,
        attachments_by_investor_id: attachments_by_investor_id
      ).call
    end

    def initialize(month:, subject:, body:, investor_ids: nil, force: true, attachments_by_investor_id: {})
      @month = month
      @subject = subject
      @body = body
      @investor_ids = Array(investor_ids).presence
      @force = force
      # Investor ids are UUIDs (strings). Never use to_i — "57d1ee81…".to_i => 57.
      @attachments_by_investor_id = (attachments_by_investor_id || {}).transform_keys { |k| k.to_s }
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
          attachment: attachment
        )

        # Attachments carry binary payloads that Active Job may not serialize safely.
        if attachment
          message.deliver_now
        else
          message.deliver_later
        end

        queued << {
          investor_id: investor.id,
          email: investor.email,
          attached: !attachment.nil?,
        }
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

    def investors
      scope = Investor.where(status: 'ACTIVE').where.not(email: [nil, ''])
      scope = scope.where(id: @investor_ids) if @investor_ids
      scope.order(:id)
    end
  end
end
