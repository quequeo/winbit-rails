class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('RESEND_FROM_EMAIL', 'Winbit <onboarding@resend.dev>')
  layout "mailer"

  private

  def backoffice_url(path = '')
    host = ENV.fetch('APP_HOST', 'localhost:3000')
    protocol = Rails.env.production? ? 'https' : 'http'
    "#{protocol}://#{host}#{path}"
  end

  # Formato argentino miles con punto, decimales con coma (sin símbolo $).
  def format_currency(amount)
    num = amount.to_f.round(2)
    formatted = sprintf('%.2f', num)
    parts = formatted.split('.')
    parts[0].gsub!(/(\d)(?=(\d{3})+(?!\d))/, "\\1.")
    "$#{parts[0]},#{parts[1]}"
  end

  def format_amount_with_unit(amount, unit)
    num = amount.to_f.round(2)
    formatted = sprintf('%.2f', num)
    parts = formatted.split('.')
    parts[0].gsub!(/(\d)(?=(\d{3})+(?!\d))/, "\\1.")
    "#{parts[0]},#{parts[1]} #{unit}"
  end

  def format_usdt_amount(amount)
    format_amount_with_unit(amount, 'USDT')
  end

  def ars_request?(request)
    %w[CASH_ARS TRANSFER_ARS].include?(request.method.to_s.upcase)
  end

  # Monto de la solicitud con unidad acorde al método (ARS en pesos; resto en USDT).
  def request_amount_label(request)
    unit = ars_request?(request) ? 'ARS' : 'USDT'
    format_amount_with_unit(request.amount, unit)
  end

  def format_amount_for_request(amount, request)
    unit = ars_request?(request) ? 'ARS' : 'USDT'
    format_amount_with_unit(amount, unit)
  end

  def requested_at_label(request)
    request.requested_at.strftime('%d/%m/%Y – %H:%M hs')
  end

  def method_label(request)
    case request.method&.upcase
    when 'USDT', 'USDC'
      request.network.present? ? "#{request.method} (#{request.network})" : request.method.to_s
    when 'LEMON_CASH'
      'Lemon Cash'
    when 'CASH'
      'Efectivo'
    when 'CASH_ARS'
      'Efectivo ARS'
    when 'CASH_USD'
      'Efectivo USD'
    when 'SWIFT'
      'SWIFT'
    when 'TRANSFER_ARS'
      'Transferencia ARS'
    when 'CRYPTO'
      request.network.present? ? "Crypto (#{request.network})" : 'Crypto'
    else
      request.method || 'No especificado'
    end
  end

  def cash_request?(request)
    %w[CASH CASH_ARS CASH_USD].include?(request.method.to_s.upcase)
  end
end
