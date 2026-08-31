# frozen_string_literal: true

module InvestorMonthlyReportEmails
  # Sends monthly report emails with the stored PDF attached. Reuses campaign mailer.
  class Send
    def self.call(month:, subject:, body:, investor_ids: nil)
      new(month: month, subject: subject, body: body, investor_ids: investor_ids).call
    end

    def initialize(month:, subject:, body:, investor_ids: nil)
      @month = month
      @subject = subject
      @body = body
      @investor_ids = Array(investor_ids).presence
    end

    def call
      audience = Audience.call(month: @month)
      eligible = audience.eligible
      eligible = eligible.select { |row| @investor_ids.include?(row.investor.id) } if @investor_ids

      ids = eligible.map { |row| row.investor.id }
      return empty_result if ids.empty?

      attachments = attachments_for(ids)
      ids_with_pdf = attachments.keys
      return empty_result if ids_with_pdf.empty?

      EmailCampaigns::Send.call(
        month: @month,
        subject: @subject,
        body: @body,
        investor_ids: ids_with_pdf,
        force: true,
        attachments_by_investor_id: attachments
      )
    end

    private

    def attachments_for(investor_ids)
      InvestorMonthlyReportPdf.for_month(@month)
        .where(investor_id: investor_ids)
        .includes(:investor)
        .each_with_object({}) do |pdf, hash|
          hash[pdf.investor_id.to_s] = EmailCampaigns::Attachment::Payload.new(
            filename: pdf.email_attachment_filename,
            content: pdf.pdf_data,
            content_type: pdf.content_type.presence || 'application/pdf'
          )
        end
    end

    def empty_result
      EmailCampaigns::Send::Result.new(
        queued: [],
        skipped: [],
        failures: [],
        total_audience: 0
      )
    end
  end
end
