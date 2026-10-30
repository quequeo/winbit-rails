# frozen_string_literal: true

module InvestorMonthlyReportEmails
  # Envía los reportes mensuales programados cuya hora ya llegó. Lo ejecuta
  # el ticker de correos cada minuto.
  #
  # Antes de enviar marca el registro como SENDING (con lock de fila): si el
  # proceso se corta a mitad del envío no se vuelve a mandar solo, para no
  # duplicar mails; queda en SENDING para revisarlo a mano. Los errores por
  # inversor ya los junta EmailCampaigns::Send en `failures`.
  class SendScheduled
    def self.call(now: Time.current)
      ScheduledMonthlyReportEmail.due(now).to_a.count { |scheduled| deliver(scheduled) }
    end

    def self.deliver(scheduled)
      claimed = scheduled.with_lock do
        next false unless scheduled.status == 'SCHEDULED'

        scheduled.update!(status: 'SENDING')
      end
      return false unless claimed

      result = Send.call(month: scheduled.month, subject: scheduled.subject, body: scheduled.body)
      scheduled.update!(
        status: 'SENT',
        sent_at: Time.current,
        queued_count: result.queued.size,
        skipped_count: result.skipped.size,
        failure_count: result.failures.size,
      )
      true
    end
  end
end
