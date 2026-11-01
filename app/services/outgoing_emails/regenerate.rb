# frozen_string_literal: true

module OutgoingEmails
  # Vuelve a armar un borrador pendiente de ingreso o retiro aprobado con los
  # textos vigentes, y regenera su comprobante, para que salga con el
  # formato actual. Mantiene el estado y la hora programada.
  class Regenerate
    class NotRegenerable < StandardError; end

    def self.call(outgoing_email:)
      new(outgoing_email:).call
    end

    def initialize(outgoing_email:)
      @email = outgoing_email
    end

    def call
      raise NotRegenerable, 'Este correo ya fue enviado o descartado' unless @email.pending?
      raise NotRegenerable, 'Solo se pueden actualizar los correos de ingresos y retiros aprobados' unless @email.with_receipt?

      request = @email.investor_request
      raise NotRegenerable, 'La solicitud ya no está aprobada' unless request.status == 'APPROVED'

      rendered = Draft.new(kind: @email.kind, investor: @email.investor, request: request, options: {}).rendered
      RequestReceiptPdfs::Generate.call(request: request)
      @email.update!(rendered)
      @email
    end
  end
end
