# frozen_string_literal: true

module OutgoingEmails
  # Confirma un borrador revisado: queda programado y sale solo a la hora que
  # corresponde. Si la hora sugerida ya pasó, se recalcula con la hora actual.
  # Con `at` se elige otra fecha y hora, también para un correo ya programado.
  class Schedule
    class InvalidTime < StandardError; end

    def self.call(outgoing_email:, scheduled_by: nil, at: nil)
      new(outgoing_email:, scheduled_by:, at:).call
    end

    def initialize(outgoing_email:, scheduled_by: nil, at: nil)
      @email = outgoing_email
      @scheduled_by = scheduled_by
      @at = at
    end

    def call
      allowed = @at.present? ? OutgoingEmail::PENDING_STATUSES : OutgoingEmail::UNSCHEDULED_STATUSES
      unless allowed.include?(@email.status)
        raise StandardError, @at.present? ? 'Este correo ya fue enviado o descartado' : 'Este correo ya está programado'
      end

      @email.update!(status: 'SCHEDULED', scheduled_for: send_time, scheduled_by: @scheduled_by, error: nil)
      @email
    end

    private

    def send_time
      return chosen_time if @at.present?
      return @email.scheduled_for if @email.scheduled_for&.future?

      SendSchedule.call(requested_at: @email.investor_request&.requested_at, approved_at: Time.current)
    end

    def chosen_time
      time = @at.is_a?(String) ? Time.zone.parse(@at) : @at
      raise InvalidTime, 'La fecha y hora no es válida' if time.nil?
      raise InvalidTime, 'La fecha y hora tiene que ser futura' unless time.future?

      time
    rescue ArgumentError
      raise InvalidTime, 'La fecha y hora no es válida'
    end
  end
end
