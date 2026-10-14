# frozen_string_literal: true

require 'net/smtp'

module OutgoingEmails
  class SendEmail
    class DeliveryFailed < StandardError; end

    DELIVERY_ERRORS = [
      Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError,
      IOError, OpenSSL::SSL::SSLError
    ].freeze

    def self.call(outgoing_email:, sent_by: nil)
      new(outgoing_email:, sent_by:).call
    end

    def initialize(outgoing_email:, sent_by: nil)
      @email = outgoing_email
      @sent_by = sent_by
    end

    def call
      raise StandardError, 'Este correo ya fue enviado o descartado' unless @email.pending?

      InvestorMailer.reviewed_message(@email).deliver_now
      @email.update!(status: 'SENT', sent_at: Time.current, sent_by: @sent_by, error: nil)
      @email
    rescue *DELIVERY_ERRORS => e
      @email.update!(status: 'FAILED', error: "#{e.class}: #{e.message}")
      raise DeliveryFailed, "No se pudo enviar el correo: #{e.message}"
    end
  end
end
