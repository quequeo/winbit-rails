# frozen_string_literal: true

# Tipo de cuenta según el capital administrado: Inversor (hasta USD 25.000),
# Core (desde USD 25.000) y Gold (desde USD 50.000).
module AccountType
  Tier = Struct.new(:name, :minimum, :percentage, keyword_init: true)

  TIERS = [
    Tier.new(name: 'Gold', minimum: 50_000, percentage: 20),
    Tier.new(name: 'Core', minimum: 25_000, percentage: 25),
    Tier.new(name: 'Inversor', minimum: 0, percentage: 30),
  ].freeze

  module_function

  def for_capital(capital)
    amount = BigDecimal(capital.to_s)
    TIERS.find { |tier| amount >= tier.minimum }
  end
end
