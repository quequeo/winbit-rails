# frozen_string_literal: true

module PushNotifications
  # Aviso al celular cuando Winbit aprueba o rechaza una solicitud de ingreso o
  # retiro. Solo esos dos momentos: el resto ya se ve en la app.
  class RequestProcessed
    MESSAGES = {
      %w[DEPOSIT APPROVED] => [ 'Depósito acreditado', 'Se acreditó tu depósito. Abrí la app para ver el detalle.' ],
      %w[WITHDRAWAL APPROVED] => [ 'Retiro procesado', 'Se procesó tu retiro. Abrí la app para ver el detalle.' ],
      %w[DEPOSIT REJECTED] => [ 'Depósito rechazado', 'Tu solicitud de depósito fue rechazada. Abrí la app para ver el detalle.' ],
      %w[WITHDRAWAL REJECTED] => [ 'Retiro rechazado', 'Tu solicitud de retiro fue rechazada. Abrí la app para ver el detalle.' ],
    }.freeze

    def self.call(request:, outcome:)
      title, body = MESSAGES[[ request.request_type, outcome ]]
      return 0 unless title

      Send.call(investor: request.investor, title: title, body: body, url: '/', tag: "request-#{request.id}")
    end
  end
end
