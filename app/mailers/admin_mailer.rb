# frozen_string_literal: true

# Mailer para notificaciones a administradores
class AdminMailer < ApplicationMailer
  OPERATIONS_INBOX = 'winbit.cfds@gmail.com'

  # Email cuando se crea una nueva solicitud de depósito
  def new_deposit_notification(request)
    @request = request
    @investor = request.investor
    @amount_label = request_amount_label(request)
    @previous_balance_usdt = format_usdt_amount(@investor.portfolio&.current_balance || 0)
    @review_url = backoffice_url("/requests")
    @method_label = method_label(request)
    @requested_at_label = requested_at_label(request)

    mail(
      to: operations_inbox,
      subject: "[Winbit] Nueva solicitud DEPÓSITO · #{@investor.name} · #{@amount_label}"
    )
  end

  # Email cuando se crea una nueva solicitud de retiro
  def new_withdrawal_notification(request)
    @request = request
    @investor = request.investor
    @amount_label = request_amount_label(request)
    @current_balance_usdt = format_usdt_amount(@investor.portfolio&.current_balance || 0)
    bal = BigDecimal((@investor.portfolio&.current_balance || 0).to_s)
    est_after = (bal - BigDecimal(request.amount.to_s)).round(2, :half_up)
    @estimated_balance_usdt = format_usdt_amount(est_after)
    @review_url = backoffice_url("/requests")
    @method_label = method_label(request)
    @requested_at_label = requested_at_label(request)
    @is_full = request.amount >= (@investor.portfolio&.current_balance || 0) * 0.99

    mail(
      to: operations_inbox,
      subject: "[Winbit] Nueva solicitud RETIRO · #{@investor.name} · #{@amount_label}"
    )
  end

  # Email cuando se aprueba un retiro y se aplica fee por retiro.
  def withdrawal_approved_notification(request, withdrawal_fee = nil)
    @request = request
    @investor = request.investor
    @amount = format_currency(request.amount)
    fee_amount = BigDecimal(withdrawal_fee&.dig(:fee_amount).presence.to_s.presence || '0')
    total_deducted = (BigDecimal(request.amount.to_s) + fee_amount).round(2, :half_up)
    @withdrawal_fee_amount = format_currency(fee_amount)
    @total_deducted = format_currency(total_deducted)
    @show_withdrawal_fee = fee_amount.positive?
    @review_url = backoffice_url('/requests')

    mail(
      to: operations_inbox,
      subject: "Retiro aprobado de #{@investor.name} - #{@amount}"
    )
  end

  private

  def operations_inbox
    [OPERATIONS_INBOX.downcase]
  end
end
