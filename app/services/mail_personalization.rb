# frozen_string_literal: true

# Saludo, fechas y plazos de los mails al inversor. El saludo es siempre
# "Hola" y las fechas van en dd/mm/aaaa (nunca "hoy" ni "ayer"), porque el
# mail se puede leer a cualquier hora. Los marcadores GREETING_TOKEN y
# REQUESTED_TOKEN quedan para los borradores generados con el formato
# anterior.
module MailPersonalization
  ZONE = ActiveSupport::TimeZone['America/Argentina/Buenos_Aires']
  GREETING_TOKEN = '%%SALUDO%%'
  REQUESTED_TOKEN = '%%SOLICITADO%%'
  CUTOFF_HOUR = 16

  module_function

  def greeting(_at = nil)
    'Hola'
  end

  def requested_when(requested_at, _at = nil)
    return 'recientemente' if requested_at.blank?

    "el #{short_date(requested_at)}"
  end

  def apply(html, requested_at:, at: nil)
    html.to_s
        .gsub(GREETING_TOKEN, greeting(at))
        .gsub(REQUESTED_TOKEN, requested_when(requested_at, at))
  end

  def short_date(time)
    return nil if time.blank?

    time.in_time_zone(ZONE).strftime('%d/%m/%Y')
  end

  # Plazo del mail "Solicitud recibida": lo pedido un día hábil hasta las
  # 16:00 se procesa ese día antes de las 18:00; el resto, desde las 8:00
  # del día hábil siguiente.
  def processing_term(requested_at)
    local = requested_at.in_time_zone(ZONE)
    if local.on_weekday? && local.hour < CUTOFF_HOUR
      'La vamos a procesar hoy antes de las 18:00.'
    else
      'La vamos a procesar a partir de las 8:00 del próximo día hábil.'
    end
  end

  def first_name(full_name)
    first = full_name.to_s.split.first.to_s
    first == first.upcase ? first.capitalize : first
  end
end
