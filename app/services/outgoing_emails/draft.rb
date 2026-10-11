# frozen_string_literal: true

module OutgoingEmails
  # Renderiza uno de los mails existentes de InvestorMailer (sin enviarlo) y
  # lo deja guardado como borrador para que un admin lo revise y confirme.
  class Draft
    def self.call(kind:, investor:, request: nil, **options)
      new(kind:, investor:, request:, options:).call
    end

    def initialize(kind:, investor:, request:, options:)
      @kind = kind
      @investor = investor
      @request = request
      @options = options
    end

    def call
      return nil if @investor.email.blank?

      message = build_message
      OutgoingEmail.create!(
        investor: @investor,
        investor_request: @request,
        kind: @kind,
        to_email: @investor.email,
        subject: message.subject,
        body_html: html_body(message)
      )
    end

    private

    def build_message
      case @kind
      when 'DEPOSIT_APPROVED'
        InvestorMailer.deposit_approved(@investor, @request, force: true).message
      when 'WITHDRAWAL_APPROVED'
        InvestorMailer.withdrawal_approved(@investor, @request, @options[:withdrawal_fee], force: true).message
      when 'DEPOSIT_REJECTED'
        InvestorMailer.deposit_rejected(@investor, @request, @options[:reason], force: true).message
      when 'WITHDRAWAL_REJECTED'
        InvestorMailer.withdrawal_rejected(@investor, @request, @options[:reason], force: true).message
      else
        raise ArgumentError, "Tipo de mail no soportado: #{@kind}"
      end
    end

    def html_body(message)
      (message.html_part || message).body.decoded
    end
  end
end
