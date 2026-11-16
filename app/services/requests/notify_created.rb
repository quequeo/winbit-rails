# frozen_string_literal: true

module Requests
  # Avisos de una solicitud nueva de ingreso o retiro:
  # - al inversor, "recibimos tu solicitud", si las notificaciones a
  #   inversores están habilitadas (NotificationGate);
  # - a operaciones (contacto@), siempre.
  #
  # Salen en el momento (no en segundo plano), así no se pierden si el
  # servidor se reinicia. El del inversor queda registrado en Correos con su
  # estado: Enviado, Falló el envío (se puede reenviar desde Correos) o No
  # enviado porque las notificaciones están apagadas.
  #
  # Nunca hace fallar la solicitud: los errores se registran y se siguen.
  class NotifyCreated
    INVESTOR_KINDS = {
      'DEPOSIT' => 'DEPOSIT_RECEIVED',
      'WITHDRAWAL' => 'WITHDRAWAL_RECEIVED',
    }.freeze
    SKIPPED_REASON = 'No salió: las notificaciones a inversores están apagadas ' \
                     '(Admin → Admins → Configuración).'

    def self.call(request:)
      new(request:).call
    end

    def initialize(request:)
      @request = request
      @investor = request.investor
    end

    def call
      return unless INVESTOR_KINDS.key?(@request.request_type)

      notify_investor
      notify_operations
    end

    private

    def notify_investor
      return if @investor.email.blank?

      email = OutgoingEmail.create!(
        investor: @investor,
        investor_request: @request,
        kind: INVESTOR_KINDS.fetch(@request.request_type),
        to_email: @investor.email,
        status: 'DRAFT',
        **rendered_investor_message
      )

      unless NotificationGate.should_send_to_investor?(@investor.email)
        NotificationGate.log_blocked_notification(@investor.email, email.kind)
        email.update!(status: 'SKIPPED', error: SKIPPED_REASON)
        return
      end

      OutgoingEmails::SendEmail.call(outgoing_email: email)
    rescue StandardError => e
      Rails.logger.error("[Requests::NotifyCreated] Aviso al inversor #{@request.id}: #{e.class}: #{e.message}")
      email.update(status: 'FAILED', error: "#{e.class}: #{e.message}") if email&.persisted? && email.status == 'DRAFT'
    end

    def notify_operations
      mail =
        if @request.request_type == 'DEPOSIT'
          AdminMailer.new_deposit_notification(@request)
        else
          AdminMailer.new_withdrawal_notification(@request)
        end
      mail.deliver_now
    rescue StandardError => e
      Rails.logger.error("[Requests::NotifyCreated] Aviso a operaciones #{@request.id}: #{e.class}: #{e.message}")
    end

    # Asunto y cuerpos del mail "recibimos tu solicitud", armados aunque las
    # notificaciones estén apagadas, para que el registro muestre qué hubiera
    # salido.
    def rendered_investor_message
      message =
        if @request.request_type == 'DEPOSIT'
          InvestorMailer.deposit_created(@investor, @request, force: true).message
        else
          InvestorMailer.withdrawal_created(@investor, @request, force: true).message
        end

      {
        subject: message.subject,
        body_html: (message.html_part || message).body.decoded,
        body_text: message.text_part&.body&.decoded,
      }
    end
  end
end
