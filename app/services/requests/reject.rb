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

      # Send rejection email notification
      begin
        if req.request_type == 'DEPOSIT'
          InvestorMailer.deposit_rejected(req.investor, req, @notes).deliver_later
        elsif req.request_type == 'WITHDRAWAL'
          InvestorMailer.withdrawal_rejected(req.investor, req, @notes).deliver_later
        end
      rescue => e
        Rails.logger.error("Failed to send rejection email: #{e.message}")
        # Continue even if email fails
      end

      true
    end
  end
end
