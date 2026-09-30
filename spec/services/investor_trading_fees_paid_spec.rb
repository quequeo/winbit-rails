# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorTradingFeesPaid do
  let(:investor) { Investor.create!(email: 'fees-paid@test.com', name: 'T', status: 'ACTIVE') }

  it 'sums TRADING_FEE amounts as a positive total' do
    PortfolioHistory.create!(
      investor: investor, event: 'TRADING_FEE', amount: -49.94,
      previous_balance: 1000, new_balance: 950.06, status: 'COMPLETED', date: Time.zone.parse('2026-06-30 17:00:00'),
    )

    total = described_class.total(investor_id: investor.id)

    expect(total).to eq(BigDecimal('49.94'))
  end

  it 'nets a TRADING_FEE_ADJUSTMENT (refund) against the original charge' do
    PortfolioHistory.create!(
      investor: investor, event: 'TRADING_FEE', amount: -100,
      previous_balance: 1000, new_balance: 900, status: 'COMPLETED', date: Time.zone.parse('2026-06-01 17:00:00'),
    )
    PortfolioHistory.create!(
      investor: investor, event: 'TRADING_FEE_ADJUSTMENT', amount: 100,
      previous_balance: 900, new_balance: 1000, status: 'COMPLETED', date: Time.zone.parse('2026-06-02 17:00:00'),
    )

    total = described_class.total(investor_id: investor.id)

    expect(total).to eq(BigDecimal('0'))
  end

  it 'only counts fees within the given from/to window' do
    PortfolioHistory.create!(
      investor: investor, event: 'TRADING_FEE', amount: -30,
      previous_balance: 1000, new_balance: 970, status: 'COMPLETED', date: Time.zone.parse('2025-12-15 17:00:00'),
    )
    PortfolioHistory.create!(
      investor: investor, event: 'TRADING_FEE', amount: -20,
      previous_balance: 970, new_balance: 950, status: 'COMPLETED', date: Time.zone.parse('2026-03-01 17:00:00'),
    )

    total = described_class.total(investor_id: investor.id, from: Time.zone.parse('2026-01-01 00:00:00'))

    expect(total).to eq(BigDecimal('20'))
  end

  it 'returns zero when the investor has never been charged a fee' do
    expect(described_class.total(investor_id: investor.id)).to eq(BigDecimal('0'))
  end
end
