module Requests
  class Reject
    def initialize(request_id:, notes: 'Rechazado por el administrador')
      @request_id = request_id
      @notes = notes
    end

    def call
      req = InvestorRequest.includes(:investor).find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo se pueden rechazar solicitudes pendientes' unless req.status == 'PENDING'

      req.update!(status: 'REJECTED', processed_at: Time.current, notes: @notes)

      # Leave the rejection email as a draft for admin review
      begin
        if req.request_type == 'DEPOSIT'
          OutgoingEmails::Draft.call(kind: 'DEPOSIT_REJECTED', investor: req.investor, request: req, reason: @notes)
        elsif req.request_type == 'WITHDRAWAL'
          OutgoingEmails::Draft.call(kind: 'WITHDRAWAL_REJECTED', investor: req.investor, request: req, reason: @notes)
        end
      rescue => e
        Rails.logger.error("Failed to send rejection email: #{e.message}")
        # Continue even if email fails
      end

      true
    end
  end
end
