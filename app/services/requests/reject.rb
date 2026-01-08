module Requests
  class Reject
    def initialize(request_id:, notes: 'Rechazado por el administrador')
      @request_id = request_id
      @notes = notes
    end

    def call
      req = InvestorRequest.find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo se pueden rechazar solicitudes pendientes' unless req.status == 'PENDING'

      req.update!(status: 'REJECTED', processed_at: Time.current, notes: @notes)
      true
    end
  end
end
