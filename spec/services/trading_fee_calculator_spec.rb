require 'rails_helper'

RSpec.describe TradingFeeCalculator do
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0) }

  def make_history(event:, amount:, date:)
    PortfolioHistory.create!(
      investor: investor,
      event: event,
      amount: amount,
      previous_balance: 0,
      new_balance: amount,
      status: 'COMPLETED',
      date: date,
    )
  end

  it 'returns last completed quarter range based on reference_date' do
    # reference_date in Q1 2026 -> last completed quarter is Q4 2025
    calc = described_class.new(investor, reference_date: Date.new(2026, 1, 21))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2025, 10, 1))
    expect(result[:period_end]).to eq(Date.new(2025, 12, 31))
  end

  it 'sums OPERATING_RESULT within the calculated period (COMPLETED only)' do
    make_history(event: 'OPERATING_RESULT', amount: 10, date: Time.zone.local(2025, 10, 10, 12, 0, 0))
    make_history(event: 'OPERATING_RESULT', amount: 5, date: Time.zone.local(2025, 12, 31, 16, 0, 0))
    make_history(event: 'OPERATING_RESULT', amount: 999, date: Time.zone.local(2026, 1, 2, 12, 0, 0))

    # Not counted: wrong status
    PortfolioHistory.create!(
      investor: investor,
      event: 'OPERATING_RESULT',
      amount: 50,
      previous_balance: 0,
      new_balance: 0,
      status: 'PENDING',
      date: Time.zone.local(2025, 11, 10, 12, 0, 0),
    )

    calc = described_class.new(investor, reference_date: Date.new(2026, 1, 21))
    result = calc.calculate

    expect(result[:profit_amount]).to eq(15.0)
  end

  it 'uses existing TradingFee period for last completed quarter if present' do
    user = User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '1')

    TradingFee.create!(
      investor: investor,
      applied_by: user,
      period_start: Date.new(2025, 10, 1),
      period_end: Date.new(2025, 12, 31),
      profit_amount: 100,
      fee_percentage: 30,
      fee_amount: 30,
      applied_at: Time.current,
    )

    calc = described_class.new(investor, reference_date: Date.new(2026, 1, 21))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2025, 10, 1))
    expect(result[:period_end]).to eq(Date.new(2025, 12, 31))
  end

  it 'returns last completed year range when investor is ANNUAL' do
    investor.update!(trading_fee_frequency: 'ANNUAL')

    calc = described_class.new(investor, reference_date: Date.new(2026, 1, 21))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2025, 1, 1))
    expect(result[:period_end]).to eq(Date.new(2025, 12, 31))
  end

  it 'returns last completed month range when investor is MONTHLY' do
    investor.update!(trading_fee_frequency: 'MONTHLY')

    calc = described_class.new(investor, reference_date: Date.new(2026, 1, 21))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2025, 12, 1))
    expect(result[:period_end]).to eq(Date.new(2025, 12, 31))
  end
end
