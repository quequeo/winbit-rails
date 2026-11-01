# frozen_string_literal: true

# Mailer para notificaciones a inversores
class InvestorMailer < ApplicationMailer
  helper_method :frontend_url
  # === DEPÓSITOS ===

  # Email cuando el cliente crea una solicitud de depósito
  def deposit_created(investor, request)
    assign_request_received(investor, request)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Solicitud de ingreso recibida | #{@amount_label}"
    )
  end

  # Email cuando el admin aprueba el depósito: bienvenida si es el aporte
  # inicial, confirmación de ingreso si no. Mismos datos que el comprobante.
  def deposit_approved(investor, request, force: false)
    assign_movement(investor, request)

    return if !force && !NotificationGate.should_send_to_investor?(investor.email)

    if @data[:kind] == :aporte
      @fee_example = MoneyFormat.usd(BigDecimal(investor.trading_fee_percentage.to_s))
      mail(
        to: investor.email,
        subject: "Winbit | Bienvenida y aporte de capital | #{@data[:amount_label]}",
        template_name: 'initial_deposit_approved'
      )
    else
      mail(
        to: investor.email,
        subject: "Winbit | Ingreso acreditado | #{@data[:amount_label]}"
      )
    end
  end

  # Email cuando el admin rechaza el depósito
  def deposit_rejected(investor, request, reason = nil, force: false)
    assign_rejection(investor, request, reason)

    return if !force && !NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Ingreso no procesado | #{@amount_label}"
    )
  end

  # === RETIROS ===

  # Email cuando el cliente solicita un retiro
  def withdrawal_created(investor, request)
    assign_request_received(investor, request)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Solicitud de retiro recibida | #{@amount_label}"
    )
  end

  # Email cuando el admin aprueba el retiro. La comisión sale del mismo
  # registro que el comprobante (TradingFee del retiro), no de un parámetro.
  def withdrawal_approved(investor, request, _withdrawal_fee = nil, force: false)
    assign_movement(investor, request)

    return if !force && !NotificationGate.should_send_to_investor?(investor.email)

    if @data[:kind] == :retiro_total
      mail(
        to: investor.email,
        subject: "Winbit | Retiro total procesado | #{@data[:amount_label]}",
        template_name: 'withdrawal_total_approved'
      )
    else
      mail(
        to: investor.email,
        subject: "Winbit | Retiro procesado | #{@data[:amount_label]}"
      )
    end
  end

  # Email cuando el admin rechaza el retiro
  def withdrawal_rejected(investor, request, reason = nil, force: false)
    assign_rejection(investor, request, reason)

    return if !force && !NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Retiro no procesado | #{@amount_label}"
    )
  end

  # === CAMPAÑAS ADMIN ===

  # Email de campaña personalizado (informe mensual, etc.).
  # force: true omite NotificationGate — solo para envíos iniciados por admin.
  # attachment: optional Hash/Payload with :filename, :content, :content_type (PDF/XLSX).
  # to: sends to another address instead of the investor's (test sends).
  def campaign_message(investor, subject:, body_html:, force: false, attachment: nil, to: nil)
    @investor = investor
    @body_html = body_html
    # A [Botón: ...] written in the body replaces the default button at the end.
    @body_has_button = body_html.to_s.include?(EmailCampaigns::TemplateRenderer::BUTTON_STYLE)

    unless force
      return unless NotificationGate.should_send_to_investor?(investor.email)
    end

    return if investor.email.blank? && to.blank?

    attach_campaign_file(attachment) if attachment.present?

    mail(
      to: to.presence || investor.email,
      subject: subject.to_s
    )
  end

  # Mail revisado y confirmado por un admin (OutgoingEmail): cuerpo ya
  # renderizado; adjunta el comprobante PDF cuando corresponde.
  def reviewed_message(outgoing_email)
    if outgoing_email.with_receipt?
      request = outgoing_email.investor_request
      receipt = request.receipt_pdf || RequestReceiptPdfs::Generate.call(request: request)
      attachments[RequestReceiptPdfs::Generate.filename_for(request)] = {
        mime_type: receipt.content_type,
        content: receipt.pdf_data,
      }
    end

    requested_at = outgoing_email.investor_request&.requested_at
    mail(to: outgoing_email.to_email, subject: outgoing_email.subject) do |format|
      if outgoing_email.body_text.present?
        text = MailPersonalization.apply(outgoing_email.body_text, requested_at: requested_at)
        format.text { render plain: text }
      end
      body = MailPersonalization.apply(outgoing_email.body_html, requested_at: requested_at)
      format.html { render html: body.html_safe, layout: false }
    end
  end

  private

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'https://app.winbit.com.ar')
  end

  def assign_movement(investor, request)
    @investor = investor
    @request = request
    @data = RequestReceiptPdfs::DocumentData.call(request: request)
  end

  def assign_rejection(investor, request, reason)
    @investor = investor
    @request = request
    @first_name = MailPersonalization.first_name(investor.name)
    @amount_label = MoneyFormat.amount(request.amount, request.currency)
    @requested_on = MailPersonalization.short_date(request.requested_at)
    @reason = rejection_reason(reason)
  end

  def assign_request_received(investor, request)
    @investor = investor
    @request = request
    @first_name = MailPersonalization.first_name(investor.name)
    @amount_label = MoneyFormat.amount(request.amount, request.currency)
    requested_at = (request.requested_at || Time.current).in_time_zone(MailPersonalization::ZONE)
    @requested_on = requested_at.strftime('%d/%m/%Y')
    @requested_time = requested_at.strftime('%H:%M')
    @processing_term = MailPersonalization.processing_term(requested_at)
    @cash_request = cash_request?(request)
  end

  def attach_campaign_file(attachment)
    payload =
      if attachment.respond_to?(:filename) && attachment.respond_to?(:content)
        attachment
      else
        attachment = attachment.with_indifferent_access
        EmailCampaigns::Attachment::Payload.new(
          filename: attachment[:filename],
          content: attachment[:content],
          content_type: attachment[:content_type]
        )
      end

    attachments[payload.filename] = {
      mime_type: payload.content_type,
      content: payload.content,
    }
  end
end
