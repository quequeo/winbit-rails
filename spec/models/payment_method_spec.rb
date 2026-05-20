require 'rails_helper'

RSpec.describe PaymentMethod, type: :model do
  it 'is valid with required attributes' do
    pm = PaymentMethod.new(
      code: 'TEST_PM',
      name: 'Test',
      kind: 'FIAT',
      active: true,
      enabled_for_deposit: true,
      enabled_for_withdrawal: true,
    )
    expect(pm).to be_valid
  end

  it 'scopes withdrawal methods' do
    PaymentMethod.find_or_create_by!(code: 'LEMON_CASH') do |pm|
      pm.name = 'Lemon Cash'
      pm.kind = 'FIAT'
      pm.enabled_for_deposit = true
      pm.enabled_for_withdrawal = true
      pm.requires_lemontag = true
    end
    PaymentMethod.find_or_create_by!(code: 'USDT') do |pm|
      pm.name = 'USDT'
      pm.kind = 'CRYPTO'
      pm.enabled_for_deposit = true
      pm.enabled_for_withdrawal = false
    end

    codes = PaymentMethod.for_flow('withdrawal').pluck(:code)
    expect(codes).to include('LEMON_CASH')
    expect(codes).not_to include('USDT')
  end
end
