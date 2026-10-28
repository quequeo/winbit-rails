# frozen_string_literal: true

# Saludo y referencia a la fecha del pedido según el momento real de envío.
# Los borradores de la bandeja guardan marcadores (GREETING_TOKEN,
# REQUESTED_TOKEN) que se completan al previsualizar y al enviar, porque la
# hora de salida (18:00 u 8:00) se conoce recién al programarlos.
module MailPersonalization
  ZONE = ActiveSupport::TimeZone['America/Argentina/Buenos_Aires']
  GREETING_TOKEN = '%%SALUDO%%'
  REQUESTED_TOKEN = '%%SOLICITADO%%'
  WEEKDAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze

  module_function

  def greeting(at)
    hour = at.in_time_zone(ZONE).hour
    if hour < 12
      'Buenos días'
    elsif hour < 20
      'Buenas tardes'
    else
      'Buenas noches'
    end
  end

  def requested_when(requested_at, at)
    return 'recientemente' if requested_at.blank?

    requested = requested_at.in_time_zone(ZONE).to_date
    days = (at.in_time_zone(ZONE).to_date - requested).to_i
    return 'el día de hoy' if days <= 0
    return 'el día de ayer' if days == 1

    "el #{WEEKDAYS[requested.wday]} #{requested.strftime('%d/%m')}"
  end

  def apply(html, requested_at:, at:)
    html.to_s
        .gsub(GREETING_TOKEN, greeting(at))
        .gsub(REQUESTED_TOKEN, requested_when(requested_at, at))
  end

  def first_name(full_name)
    first = full_name.to_s.split.first.to_s
    first == first.upcase ? first.capitalize : first
  end
end
