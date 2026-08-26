# frozen_string_literal: true

module InvestorMonthlyReportEmails
  # Preview eligible recipients and a rendered sample for monthly report emails.
  class Preview
    Result = Struct.new(
      :month,
      :audience_count,
      :variables,
      :recipients,
      :skipped,
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
      audience = Audience.call(month: @month, investor_id: @investor_id)
      sample_row = pick_sample(audience)
      sample_vars = variables_for(sample_row&.investor)

      Result.new(
        month: @month,
        audience_count: audience.eligible.size,
        variables: EmailCampaigns::MonthlyPerformanceVariables.available_variable_names,
        recipients: audience.eligible.map { |row| serialize_recipient(row) },
        skipped: audience.skipped.map { |row| serialize_skipped(row) },
        sample_subject: @subject.present? ? EmailCampaigns::TemplateRenderer.render_plain(@subject, sample_vars) : nil,
        sample_body_html: @body.present? ? EmailCampaigns::TemplateRenderer.render_html(@body, sample_vars) : nil,
        sample_investor: sample_row && {
          id: sample_row.investor.id,
          name: sample_row.investor.name,
          email: sample_row.investor.email
        }
      )
    end

    private

    def pick_sample(audience)
      return audience.eligible.first if @investor_id.blank?

      audience.rows.find { |row| row.investor.id.to_s == @investor_id.to_s } || audience.eligible.first
    end

    def serialize_recipient(row)
      investor = row.investor
      vars = variables_for(investor)
      {
        id: investor.id,
        name: investor.name,
        email: investor.email,
        has_pdf: row.has_pdf,
        balance: row.balance.to_f,
        pdf_filename: row.pdf&.email_attachment_filename,
        ganancia_usd: vars['ganancia_usd'],
        ganancia_pct: vars['ganancia_pct']
      }
    end

    def serialize_skipped(row)
      investor = row.investor
      {
        id: investor.id,
        name: investor.name,
        email: investor.email,
        has_pdf: row.has_pdf,
        balance: row.balance.to_f,
        skip_reason: row.skip_reason,
        skip_message: Audience.message_for(row.skip_reason)
      }
    end

    def variables_for(investor)
      return {} if investor.blank?

      EmailCampaigns::MonthlyPerformanceVariables.call(investor: investor, report_month: @month)
    rescue StandardError => e
      Rails.logger.error("[InvestorMonthlyReportEmails::Preview] investor=#{investor.id}: #{e.message}")
      {
        'nombre' => investor.name.to_s,
        'email' => investor.email.to_s,
        'ganancia_usd' => EmailCampaigns::MonthlyPerformanceVariables::MISSING,
        'ganancia_pct' => EmailCampaigns::MonthlyPerformanceVariables::MISSING,
        'mes' => @month.to_s
      }
    end
  end
end
