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

  it 'ignores genesis seed deposits as new inflows after reset' do
    reset_at = Time.zone.parse('2026-04-13 19:00:00')
    as_of = Time.zone.parse('2026-05-05 18:59:59')

    investor.portfolio.update!(
      genesis_vpcust_usd: 5000,
      genesis_fee_basis_at: reset_at,
    )

    InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      amount: 5000,
      method: 'USDT',
      network: 'TRC20',
      status: 'APPROVED',
      requested_at: Time.zone.parse('2026-04-30 23:59:57'),
      processed_at: Time.zone.parse('2026-04-30 23:59:57'),
      notes: 'genesis sheet snapshot (post-cleanup)',
    )

    pending = described_class.pending_until(
      investor: investor,
      as_of: as_of,
      current_balance: BigDecimal('5100.37'),
    )

    expect(pending).to eq(BigDecimal('100.37'))
  end

  it 'subtracts real deposits after reset from pending profit' do
    reset_at = Time.zone.parse('2026-04-01 19:00:00')
    as_of = Time.zone.parse('2026-05-06 12:00:00')

    investor.portfolio.update!(
      genesis_vpcust_usd: 7989,
      genesis_fee_basis_at: reset_at,
    )

    InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      amount: 100,
      method: 'USDT',
      network: 'TRC20',
      status: 'APPROVED',
      requested_at: Time.zone.parse('2026-05-06 10:00:00'),
      processed_at: Time.zone.parse('2026-05-06 10:00:00'),
      notes: 'manual deposit',
    )

    pending = described_class.pending_until(
      investor: investor,
      as_of: as_of,
      current_balance: BigDecimal('8247'),
    )

    expect(pending).to eq(BigDecimal('158'))
  end
end
