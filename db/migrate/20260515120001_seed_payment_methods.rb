class SeedPaymentMethods < ActiveRecord::Migration[8.0]
  METHODS = [
    {
      code: 'CRYPTO',
      name: 'Criptomonedas',
      kind: 'CRYPTO',
      enabled_for_deposit: true,
      enabled_for_withdrawal: true,
      requires_network: true,
      requires_lemontag: false,
      position: 10,
    },
    {
      code: 'USDT',
      name: 'USDT',
      kind: 'CRYPTO',
      enabled_for_deposit: true,
      enabled_for_withdrawal: false,
      requires_network: true,
      requires_lemontag: false,
      position: 20,
    },
    {
      code: 'USDC',
      name: 'USDC',
      kind: 'CRYPTO',
      enabled_for_deposit: true,
      enabled_for_withdrawal: false,
      requires_network: true,
      requires_lemontag: false,
      position: 30,
    },
    {
      code: 'LEMON_CASH',
      name: 'Lemon Cash',
      kind: 'FIAT',
      enabled_for_deposit: true,
      enabled_for_withdrawal: true,
      requires_network: false,
      requires_lemontag: true,
      position: 40,
    },
    {
      code: 'CASH_ARS',
      name: 'Efectivo ARS',
      kind: 'CASH',
      enabled_for_deposit: true,
      enabled_for_withdrawal: false,
      requires_network: false,
      requires_lemontag: false,
      position: 50,
    },
    {
      code: 'CASH_USD',
      name: 'Efectivo USD',
      kind: 'CASH',
      enabled_for_deposit: true,
      enabled_for_withdrawal: true,
      requires_network: false,
      requires_lemontag: false,
      position: 60,
    },
    {
      code: 'SWIFT',
      name: 'SWIFT',
      kind: 'BANK',
      enabled_for_deposit: true,
      enabled_for_withdrawal: false,
      requires_network: false,
      requires_lemontag: false,
      position: 70,
    },
  ].freeze

  def up
    METHODS.each do |attrs|
      PaymentMethod.find_or_initialize_by(code: attrs[:code]).tap do |pm|
        pm.assign_attributes(attrs.merge(active: true))
        pm.save!
      end
    end
  end

  def down
    PaymentMethod.where(code: METHODS.map { |m| m[:code] }).delete_all
  end
end
