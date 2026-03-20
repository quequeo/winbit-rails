# frozen_string_literal: true

# Mailer para notificaciones a inversores
class InvestorMailer < ApplicationMailer
  helper_method :frontend_url
  # === DEPÓSITOS ===

  # Email cuando el cliente crea una solicitud de depósito
  def deposit_created(investor, request)
    @investor = investor
    @request = request
    @amount_label = request_amount_label(request)
    @method_label = method_label(request)
    @cash_request = cash_request?(request)
    @requested_at_label = requested_at_label(request)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Solicitud de depósito recibida | #{@amount_label}"
    )
  end

  # Email cuando el admin aprueba el depósito
  def deposit_approved(investor, request)
    @investor = investor
    @request = request
    @amount_label = request_amount_label(request)
    @new_balance_usdt = format_usdt_amount(investor.portfolio&.current_balance || 0)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Depósito acreditado | #{@amount_label}"
    )
  end

  # Email cuando el admin rechaza el depósito
  def deposit_rejected(investor, request, reason = nil)
    @investor = investor
    @request = request
    @amount_label = request_amount_label(request)
    @reason = reason.presence
    @show_reason = @reason.present?

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Depósito rechazado | #{@amount_label}"
    )
  end

  # === RETIROS ===

  # Email cuando el cliente solicita un retiro
  def withdrawal_created(investor, request)
    @investor = investor
    @request = request
    @amount_label = request_amount_label(request)
    @is_full = request.amount >= (investor.portfolio&.current_balance || 0) * 0.99
    @method_label = method_label(request)
    @cash_request = cash_request?(request)
    @requested_at_label = requested_at_label(request)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Solicitud de retiro recibida | #{@amount_label}"
    )
  end

  # Email cuando el admin aprueba el retiro
  def withdrawal_approved(investor, request, withdrawal_fee = nil)
    @investor = investor
    @request = request
    @amount_label = request_amount_label(request)
    fee_amount = BigDecimal(withdrawal_fee&.dig(:fee_amount).presence.to_s.presence || '0')
    total_deducted = (BigDecimal(request.amount.to_s) + fee_amount).round(2, :half_up)
    @withdrawal_fee_amount_label = format_amount_for_request(fee_amount, request)
    @total_deducted_label = format_amount_for_request(total_deducted, request)
    @show_withdrawal_fee = fee_amount.positive?
    @new_balance_usdt = format_usdt_amount(investor.portfolio&.current_balance || 0)

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Retiro aprobado | #{@amount_label}"
    )
  end

  # Email cuando el admin rechaza el retiro
  def withdrawal_rejected(investor, request, reason = nil)
    @investor = investor
    @request = request
    @amount_label = request_amount_label(request)
    @reason = reason.presence
    @show_reason = @reason.present?

    return unless NotificationGate.should_send_to_investor?(investor.email)

    mail(
      to: investor.email,
      subject: "Winbit | Retiro rechazado | #{@amount_label}"
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

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'https://winbit-6579c.web.app')
  end
end
