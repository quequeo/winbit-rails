# frozen_string_literal: true

module OutgoingEmails
  # Fecha y hora (Argentina) en que debe salir el mail de una solicitud.
  #
  # Los mails salen siempre a las 18:00 o a las 8:00:
  # - pedida antes de las 16:00 y aprobada antes de las 18:00 -> 18:00 del mismo día
  # - pedida después de las 16:00 (el mismo día de la aprobación), o aprobada
  #   después de las 18:00 -> 8:00 del siguiente día hábil
  # - sábados y domingos no se envía: pasa al lunes a las 8:00
  class SendSchedule
    ZONE = ActiveSupport::TimeZone['America/Argentina/Buenos_Aires']
    REQUEST_CUTOFF_HOUR = 16
    EVENING_HOUR = 18
    MORNING_HOUR = 8

    def self.call(requested_at:, approved_at:)
      new(requested_at:, approved_at:).call
    end

    def initialize(requested_at:, approved_at:)
      @approved = approved_at.in_time_zone(ZONE)
      @requested = (requested_at || approved_at).in_time_zone(ZONE)
    end

    def call
      return next_business_morning if late_request? || @approved.hour >= EVENING_HOUR
      return next_business_morning if weekend?(@approved.to_date)

      at(@approved.to_date, EVENING_HOUR)
    end

    private

    def late_request?
      @requested.to_date == @approved.to_date && @requested.hour >= REQUEST_CUTOFF_HOUR
    end

    def next_business_morning
      date = @approved.to_date + 1
      date += 1 while weekend?(date)
      at(date, MORNING_HOUR)
    end

    def weekend?(date)
      date.saturday? || date.sunday?
    end

    def at(date, hour)
      ZONE.local(date.year, date.month, date.day, hour)
    end
  end
end
