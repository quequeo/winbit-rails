# frozen_string_literal: true

# Mailer para notificaciones a administradores
class AdminMailer < ApplicationMailer
  # Email cuando se crea una nueva solicitud de depósito
  def new_deposit_notification(request)
    @request = request
    @investor = request.investor
    @amount = format_currency(request.amount)
    @review_url = backoffice_url("/requests")
    @method_label = method_label(request)

    # Solo enviar a admins que tengan esta notificación activa
    admin_emails = User.notify_deposits.pluck(:email)
    return if admin_emails.empty?

    mail(
      to: admin_emails,
      subject: "Nuevo depósito de #{@investor.name} - #{@amount}"
    )
  end

  # Email cuando se crea una nueva solicitud de retiro
  def new_withdrawal_notification(request)
    @request = request
    @investor = request.investor
    @amount = format_currency(request.amount)
    @current_balance = format_currency(@investor.portfolio&.current_balance || 0)
    @review_url = backoffice_url("/requests")
    @method_label = method_label(request)
    @is_full = request.amount >= (@investor.portfolio&.current_balance || 0) * 0.99

    # Solo enviar a admins que tengan esta notificación activa
    admin_emails = User.notify_withdrawals.pluck(:email)
    return if admin_emails.empty?

    mail(
      to: admin_emails,
      subject: "Nueva solicitud de retiro de #{@investor.name} - #{@amount}"
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

  def method_label(request)
    case request.method&.upcase
    when 'USDT', 'USDC'
      "#{request.method} (#{request.network})"
    when 'LEMON_CASH'
      'Lemon Cash'
    when 'CASH'
      'Efectivo'
    else
      request.method || 'No especificado'
    end
  end
end
