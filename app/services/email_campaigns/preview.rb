# frozen_string_literal: true

module EmailCampaigns
  # Preview recipients and rendered sample for a monthly campaign.
  class Preview
    Result = Struct.new(
      :month,
      :audience_count,
      :variables,
      :recipients,
      :sample_subject,
      :sample_body_html,
      :sample_investor,
      keyword_init: true
    )

    def self.call(month:, subject: nil, body: nil, investor_id: nil)
      new(month: month, subject: subject, body: body, investor_id: investor_id).call
    end

    def initialize(month:, subject: nil, body: nil, investor_id: nil)
      @month = month
      @subject = subject
      @body = body
      @investor_id = investor_id
    end

    def call
      recipients = build_recipients
      sample = pick_sample(recipients)
      sample_vars = sample&.dig(:variables) || {}

      Result.new(
        month: @month,
        audience_count: recipients.size,
        variables: MonthlyPerformanceVariables.available_variable_names,
        recipients: recipients,
        sample_subject: @subject.present? ? TemplateRenderer.render_plain(@subject, sample_vars) : nil,
        sample_body_html: @body.present? ? TemplateRenderer.render_html(@body, sample_vars) : nil,
        sample_investor: sample && {
          id: sample[:id],
          name: sample[:name],
          email: sample[:email],
        }
      )
    end

    private

    def build_recipients
      scope = Investor.where(status: 'ACTIVE').where.not(email: [nil, '']).order(:name)
      scope = scope.where(id: @investor_id) if @investor_id.present?

      recipients = []
      scope.find_each do |investor|
        recipients << build_recipient(investor)
      end
      recipients
    end

    def build_recipient(investor)
      vars = MonthlyPerformanceVariables.call(investor: investor, report_month: @month)
      {
        id: investor.id,
        name: investor.name,
        email: investor.email,
        ganancia_usd: vars['ganancia_usd'],
        ganancia_pct: vars['ganancia_pct'],
        variables: vars.slice(*MonthlyPerformanceVariables.available_variable_names),
      }
    rescue StandardError => e
      Rails.logger.error("[EmailCampaigns::Preview] investor=#{investor.id}: #{e.message}")
      {
        id: investor.id,
        name: investor.name,
        email: investor.email,
        ganancia_usd: MonthlyPerformanceVariables::MISSING,
        ganancia_pct: MonthlyPerformanceVariables::MISSING,
        variables: {
          'nombre' => investor.name.to_s,
          'email' => investor.email.to_s,
          'ganancia_usd' => MonthlyPerformanceVariables::MISSING,
          'ganancia_pct' => MonthlyPerformanceVariables::MISSING,
          'mes' => @month.to_s,
        },
        error: e.message,
      }
    end

    def pick_sample(recipients)
      return recipients.first if @investor_id.blank?

      recipients.find { |r| r[:id].to_s == @investor_id.to_s } || recipients.first
    end
  end
end
