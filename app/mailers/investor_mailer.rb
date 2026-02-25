# frozen_string_literal: true

# Mailer para notificaciones a inversores
class InvestorMailer < ApplicationMailer
  helper_method :frontend_url
  # === DEPÓSITOS ===

  # Email cuando el cliente crea una solicitud de depósito
  def deposit_created(investor, request)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    @request_method = request.respond_to?(:method) ? request.send(:method) : request[:method]
    @request_network = request.respond_to?(:network) ? request.network : request[:network]

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: 'Depósito recibido - Pendiente de revisión'
    )
  end

  # Email cuando el admin aprueba el depósito
  def deposit_approved(investor, request)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    @new_balance = format_currency(investor.portfolio&.current_balance || 0)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: 'Depósito aprobado - Fondos acreditados'
    )
  end

  # Email cuando el admin rechaza el depósito
  def deposit_rejected(investor, request, reason = nil)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    @reason = reason || 'No se proporcionó una razón específica'

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: 'Depósito rechazado'
    )
  end

  # === RETIROS ===

  # Email cuando el cliente solicita un retiro
  def withdrawal_created(investor, request)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    @is_full = request.amount >= (investor.portfolio&.current_balance || 0) * 0.99
    @request_method = request.respond_to?(:method) ? request.send(:method) : request[:method]

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: 'Retiro solicitado - Pendiente de procesamiento'
    )
  end

  # Email cuando el admin aprueba el retiro
  def withdrawal_approved(investor, request, withdrawal_fee = nil)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    fee_amount = BigDecimal(withdrawal_fee&.dig(:fee_amount).presence.to_s.presence || '0')
    total_deducted = (BigDecimal(request.amount.to_s) + fee_amount).round(2, :half_up)
    @withdrawal_fee_amount = format_currency(fee_amount)
    @total_deducted = format_currency(total_deducted)
    @show_withdrawal_fee = fee_amount.positive?
    @new_balance = format_currency(investor.portfolio&.current_balance || 0)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: 'Retiro aprobado - Fondos enviados'
    )
  end

  # Email cuando el admin rechaza el retiro
  def withdrawal_rejected(investor, request, reason = nil)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    @reason = reason || 'No se proporcionó una razón específica'

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: 'Retiro rechazado'
    )
  end

  # === COMISIONES DE TRADING ===

  # Email cuando se aplica una comisión de trading
  def trading_fee_applied(investor, trading_fee)
    @investor = investor
    @trading_fee = trading_fee
    @fee_amount = format_currency(trading_fee.fee_amount)
    @profit_amount = format_currency(trading_fee.profit_amount)
    @fee_percentage = trading_fee.fee_percentage
    @period_start = I18n.l(trading_fee.period_start, format: :long)
    @period_end = I18n.l(trading_fee.period_end, format: :long)
    @new_balance = format_currency(investor.portfolio&.current_balance || 0)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: 'Comisión por Servicios de Trading Aplicada'
    )
  end

  private

  def format_currency(amount)
    num = amount.to_f.round(2)
    # Asegurar siempre 2 decimales con sprintf
    formatted = sprintf('%.2f', num)
    parts = formatted.split('.')
    # Formatear miles con punto
    parts[0].gsub!(/(\d)(?=(\d{3})+(?!\d))/, "\\1.")
    # Unir con coma para decimales
    "$#{parts[0]},#{parts[1]}"
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'https://winbit-6579c.web.app')
  end
end
