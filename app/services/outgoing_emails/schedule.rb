# frozen_string_literal: true

module OutgoingEmails
  # Confirma un borrador revisado: queda programado y sale solo a la hora que
  # corresponde. Si la hora sugerida ya pasó, se recalcula con la hora actual.
  class Schedule
    def self.call(outgoing_email:, scheduled_by: nil)
      new(outgoing_email:, scheduled_by:).call
    end

    def initialize(outgoing_email:, scheduled_by: nil)
      @email = outgoing_email
      @scheduled_by = scheduled_by
    end

    def call
      unless OutgoingEmail::UNSCHEDULED_STATUSES.include?(@email.status)
        raise StandardError, 'Solo se pueden programar correos pendientes de revisión'
      end

      @email.update!(status: 'SCHEDULED', scheduled_for: send_time, scheduled_by: @scheduled_by, error: nil)
      @email
    end

    private

    def send_time
      return @email.scheduled_for if @email.scheduled_for&.future?

      SendSchedule.call(requested_at: @email.investor_request&.requested_at, approved_at: Time.current)
    end
  end
end
