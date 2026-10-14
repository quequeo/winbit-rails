# frozen_string_literal: true

module OutgoingEmails
  # Envía los correos programados cuya hora ya llegó. Lo ejecuta el ticker del
  # proceso web cada minuto; el lock de fila evita envíos dobles.
  class SendDue
    def self.call
      due = OutgoingEmail.where(status: 'SCHEDULED').where(scheduled_for: ..Time.current).to_a
      due.count { |email| deliver(email) }
    end

    def self.deliver(email)
      email.with_lock do
        next false unless email.status == 'SCHEDULED'

        begin
          SendEmail.call(outgoing_email: email, sent_by: email.scheduled_by)
          true
        rescue SendEmail::DeliveryFailed => e
          Rails.logger.error("[OutgoingEmails::SendDue] email=#{email.id}: #{e.message}")
          false
        end
      end
    end
  end
end
