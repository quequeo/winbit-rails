# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorRequest, '#currency' do
  let(:investor) { Investor.create!(email: 'currency@test.com', name: 'Currency', status: 'ACTIVE') }

  def build(method, asset: nil)
    described_class.new(investor: investor, request_type: 'DEPOSIT', method: method, amount: 10, asset: asset)
  end

  it 'uses the stored asset when present' do
    expect(build('CRYPTO', asset: 'USDC').currency).to eq('USDC')
  end

  it 'derives the currency from the method' do
    expect(build('USDT').currency).to eq('USDT')
    expect(build('USDC').currency).to eq('USDC')
    expect(build('CRYPTO').currency).to eq('USDT')
    expect(build('LEMON_CASH').currency).to eq('USDT')
    expect(build('SWIFT').currency).to eq('USD')
    expect(build('CASH_USD').currency).to eq('USD')
    expect(build('CASH_ARS').currency).to eq('ARS')
  end

  it 'only accepts USDT, USDC or USD as asset' do
    expect(build('CRYPTO', asset: 'BTC')).not_to be_valid
  end
end
