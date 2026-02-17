require 'rails_helper'

RSpec.describe TimeWeightedReturnCalculator do
  def t(y, m, d, hh, mm = 0, ss = 0)
    Time.zone.local(y, m, d, hh, mm, ss)
  end

  it 'returns 0% when investor has no history (uses current portfolio snapshot)' do
    investor = Investor.create!(email: 'nohist@example.com', name: 'nohist', status: 'ACTIVE')
    Portfolio.create!(
      investor: investor,
      current_balance: 1234.56,
      total_invested: 0,
      accumulated_return_usd: 0,
      accumulated_return_percent: 0
    )

    res = described_class.for_investor(
      investor_id: investor.id,
      from: t(2026, 1, 1, 0, 0, 0),
      to: t(2026, 1, 31, 23, 59, 59)
    )

    expect(res.twr_percent).to eq(0.0)
    expect(res.pnl_usd).to eq(0.0)
    expect(res.start_value).to be_within(0.01).of(1234.56)
    expect(res.end_value).to be_within(0.01).of(1234.56)
    expect(res.effective_start_at).to eq(t(2026, 1, 1, 0, 0, 0))
  end

  it 'returns nil effective_start_at when investor has no history and balance is 0' do
    investor = Investor.create!(email: 'nohist0@example.com', name: 'nohist0', status: 'ACTIVE')
    Portfolio.create!(
      investor: investor,
      current_balance: 0,
      total_invested: 0,
      accumulated_return_usd: 0,
      accumulated_return_percent: 0
    )

    res = described_class.for_investor(investor_id: investor.id, from: t(2026, 1, 1, 0, 0, 0))
    expect(res.twr_percent).to eq(0.0)
    expect(res.effective_start_at).to be_nil
  end

  it 'returns 0% platform return when there is no PortfolioHistory (flat AUM snapshot)' do
    i1 = Investor.create!(email: 'p1@example.com', name: 'p1', status: 'ACTIVE')
    i2 = Investor.create!(email: 'p2@example.com', name: 'p2', status: 'ACTIVE')
    Portfolio.create!(investor: i1, current_balance: 100, total_invested: 100)
    Portfolio.create!(investor: i2, current_balance: 50, total_invested: 50)

    res = described_class.for_platform(from: t(2026, 1, 1, 0, 0, 0), to: t(2026, 1, 2, 0, 0, 0))

    expect(res.twr_percent).to eq(0.0)
    expect(res.pnl_usd).to eq(0.0)
    expect(res.start_value).to eq(150.0)
    expect(res.end_value).to eq(150.0)
    expect(res.effective_start_at).to eq(t(2026, 1, 1, 0, 0, 0))
  end

  it 'computes platform TWR when flows start after range_start (effective_start_at moves)' do
    i1 = Investor.create!(email: 'plat1@example.com', name: 'plat1', status: 'ACTIVE')
    i2 = Investor.create!(email: 'plat2@example.com', name: 'plat2', status: 'ACTIVE')
    Portfolio.create!(investor: i1, current_balance: 0, total_invested: 0)
    Portfolio.create!(investor: i2, current_balance: 0, total_invested: 0)

    # Strategy starts with first deposit inside the window
    PortfolioHistory.create!(
      investor: i1,
      event: 'DEPOSIT',
      amount: 1000,
      previous_balance: 0,
      new_balance: 1000,
      status: 'COMPLETED',
      date: t(2026, 1, 10, 19, 0, 0)
    )
    # Internal performance (profit) increases balance
    PortfolioHistory.create!(
      investor: i1,
      event: 'OPERATING_RESULT',
      amount: 100,
      previous_balance: 1000,
      new_balance: 1100,
      status: 'COMPLETED',
      date: t(2026, 1, 12, 17, 0, 0)
    )

    res = described_class.for_platform(from: t(2026, 1, 1, 0, 0, 0), to: t(2026, 1, 31, 23, 59, 59))
    expect(res.effective_start_at.to_date).to eq(Date.new(2026, 1, 10))
    expect(res.twr_percent).to be_within(0.0001).of(10.0)
    expect(res.pnl_usd).to be_within(0.01).of(100.0)
  end

  it 'can restrict platform metrics to a subset of investors' do
    active = Investor.create!(email: 'subset_active@example.com', name: 'subset_active', status: 'ACTIVE')
    inactive = Investor.create!(email: 'subset_inactive@example.com', name: 'subset_inactive', status: 'INACTIVE')
    Portfolio.create!(investor: active, current_balance: 0, total_invested: 0)
    Portfolio.create!(investor: inactive, current_balance: 0, total_invested: 0)

    PortfolioHistory.create!(
      investor: active,
      event: 'DEPOSIT',
      amount: 1_000,
      previous_balance: 0,
      new_balance: 1_000,
      status: 'COMPLETED',
      date: t(2026, 1, 10, 19, 0, 0)
    )
    PortfolioHistory.create!(
      investor: active,
      event: 'OPERATING_RESULT',
      amount: 100,
      previous_balance: 1_000,
      new_balance: 1_100,
      status: 'COMPLETED',
      date: t(2026, 1, 12, 17, 0, 0)
    )

    PortfolioHistory.create!(
      investor: inactive,
      event: 'DEPOSIT',
      amount: 2_000,
      previous_balance: 0,
      new_balance: 2_000,
      status: 'COMPLETED',
      date: t(2026, 1, 10, 19, 0, 0)
    )
    PortfolioHistory.create!(
      investor: inactive,
      event: 'OPERATING_RESULT',
      amount: 500,
      previous_balance: 2_000,
      new_balance: 2_500,
      status: 'COMPLETED',
      date: t(2026, 1, 12, 17, 0, 0)
    )

    res = described_class.for_platform(
      from: t(2026, 1, 1, 0, 0, 0),
      to: t(2026, 1, 31, 23, 59, 59),
      investor_ids: [active.id]
    )

    expect(res.pnl_usd).to be_within(0.01).of(100.0)
    expect(res.twr_percent).to be_within(0.0001).of(10.0)
  end

  it 'computes investor TWR independent of withdrawals (example: +20% then withdraw)' do
    investor = Investor.create!(email: 'twr@example.com', name: 'twr', status: 'ACTIVE')
    Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0, accumulated_return_usd: 0, accumulated_return_percent: 0)

    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 10_000,
      previous_balance: 0,
      new_balance: 10_000,
      status: 'COMPLETED',
      date: t(2026, 1, 10, 19, 0, 0)
    )

    PortfolioHistory.create!(
      investor: investor,
      event: 'OPERATING_RESULT',
      amount: 2_000,
      previous_balance: 10_000,
      new_balance: 12_000,
      status: 'COMPLETED',
      date: t(2026, 1, 20, 17, 0, 0)
    )

    PortfolioHistory.create!(
      investor: investor,
      event: 'WITHDRAWAL',
      amount: 8_000,
      previous_balance: 12_000,
      new_balance: 4_000,
      status: 'COMPLETED',
      date: t(2026, 1, 21, 19, 0, 0)
    )

    res = described_class.for_investor(investor_id: investor.id, from: t(2026, 1, 1, 0, 0, 0), to: t(2026, 1, 31, 23, 59, 59))

    expect(res.twr_percent).to be_within(0.0001).of(20.0)
    expect(res.pnl_usd).to be_within(0.01).of(2000.0)
    expect(res.effective_start_at.to_date).to eq(Date.new(2026, 1, 10))
  end

  it 'treats trading fees as internal performance (reduces TWR)' do
    investor = Investor.create!(email: 'fee_twr@example.com', name: 'fee', status: 'ACTIVE')
    Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0, accumulated_return_usd: 0, accumulated_return_percent: 0)

    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 10_000,
      previous_balance: 0,
      new_balance: 10_000,
      status: 'COMPLETED',
      date: t(2026, 1, 10, 19, 0, 0)
    )

    PortfolioHistory.create!(
      investor: investor,
      event: 'OPERATING_RESULT',
      amount: 2_000,
      previous_balance: 10_000,
      new_balance: 12_000,
      status: 'COMPLETED',
      date: t(2026, 1, 20, 17, 0, 0)
    )

    # Trading fee reduces balance (internal performance)
    PortfolioHistory.create!(
      investor: investor,
      event: 'TRADING_FEE',
      amount: -300,
      previous_balance: 12_000,
      new_balance: 11_700,
      status: 'COMPLETED',
      date: t(2026, 1, 22, 17, 0, 0)
    )

    PortfolioHistory.create!(
      investor: investor,
      event: 'WITHDRAWAL',
      amount: 8_000,
      previous_balance: 11_700,
      new_balance: 3_700,
      status: 'COMPLETED',
      date: t(2026, 1, 23, 19, 0, 0)
    )

    res = described_class.for_investor(investor_id: investor.id, from: t(2026, 1, 1, 0, 0, 0), to: t(2026, 1, 31, 23, 59, 59))

    # Before the withdrawal, portfolio went from 10,000 to 11,700 => +17%
    expect(res.twr_percent).to be_within(0.0001).of(17.0)
    expect(res.pnl_usd).to be_within(0.01).of(1700.0)
  end
end
