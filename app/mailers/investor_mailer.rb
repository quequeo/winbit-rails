# frozen_string_literal: true

# Mailer para notificaciones a inversores
class InvestorMailer < ApplicationMailer
  # === DEPÓSITOS ===

  # Email cuando el cliente crea una solicitud de depósito
  def deposit_created(investor, request)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    @request_method = request.respond_to?(:method) ? request.send(:method) : request[:method]
    @request_network = request.respond_to?(:network) ? request.network : request[:network]

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

    mail(
      to: investor.email,
      subject: 'Retiro solicitado - Pendiente de procesamiento'
    )
  end

  # Email cuando el admin aprueba el retiro
  def withdrawal_approved(investor, request)
    @investor = investor
    @request = request
    @amount = format_currency(request.amount)
    @new_balance = format_currency(investor.portfolio&.current_balance || 0)

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

    mail(
      to: investor.email,
      subject: 'Retiro rechazado'
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
end
