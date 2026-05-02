# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorPendingProfit do
  let(:investor) { Investor.create!(email: 'pending-profit@example.com', name: 'T', status: 'ACTIVE') }

  before do
    Portfolio.create!(
      investor: investor,
      current_balance: 10_000,
      total_invested: 8000,
      accumulated_return_usd: 2000,
      accumulated_return_percent: 25,
      annual_return_usd: 0,
      annual_return_percent: 0,
    )
  end

  it 'uses the newer reset between genesis snapshot and portfolio history' do
    old = 2.weeks.ago
    recent = 1.day.ago

    investor.portfolio.update!(
      genesis_vpcust_usd: 9000,
      genesis_fee_basis_at: old,
    )

    PortfolioHistory.create!(
      investor_id: investor.id,
      event: 'WITHDRAWAL',
      amount: 500,
      previous_balance: 10_000,
      new_balance: 9500,
      status: 'COMPLETED',
      date: recent,
    )

    pending = described_class.pending_until(
      investor: investor,
      as_of: Time.current,
      current_balance: BigDecimal('10000'),
    )

    expect(pending).to eq(BigDecimal('500'))
  end

  it 'uses genesis snapshot when it is newer than history' do
    old = 3.weeks.ago
    mid = 1.week.ago

    PortfolioHistory.create!(
      investor_id: investor.id,
      event: 'WITHDRAWAL',
      amount: 100,
      previous_balance: 10_000,
      new_balance: 9900,
      status: 'COMPLETED',
      date: old,
    )

    investor.portfolio.update!(
      genesis_vpcust_usd: 9800,
      genesis_fee_basis_at: mid,
    )

    pending = described_class.pending_until(
      investor: investor,
      as_of: Time.current,
      current_balance: BigDecimal('10000'),
    )

    expect(pending).to eq(BigDecimal('200'))
  end
end
