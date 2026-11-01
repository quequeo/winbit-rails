# frozen_string_literal: true

# Montos en formato argentino para mails y comprobantes: USD y ARS van
# adelante (USD 4.733,28) y las monedas cripto detrás (236,00 USDT).
module MoneyFormat
  PREFIXED = %w[USD ARS EUR].freeze

  module_function

  def number(value)
    decimal = BigDecimal(value.to_s)
    integer, decimals = format('%.2f', decimal.abs.round(2, :half_up)).split('.')
    sign = decimal.negative? ? '-' : ''
    "#{sign}#{integer.gsub(/\B(?=(\d{3})+(?!\d))/, '.')},#{decimals}"
  end

  def amount(value, currency)
    PREFIXED.include?(currency) ? "#{currency} #{number(value)}" : "#{number(value)} #{currency}"
  end

  def usd(value)
    amount(value, 'USD')
  end

  def percentage(value)
    format('%g', BigDecimal(value.to_s).round(2)).tr('.', ',')
  end
end
