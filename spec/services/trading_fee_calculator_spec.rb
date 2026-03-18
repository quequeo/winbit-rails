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

  it 'adjusts period when withdrawal fee was charged in the middle of the month' do
    investor.update!(trading_fee_frequency: 'MONTHLY')
    user = User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '1')
    wd_req = InvestorRequest.create!(investor: investor, request_type: 'WITHDRAWAL', amount: 20, method: 'USDT', status: 'APPROVED')

    # Operativa feb 1-12
    make_history(event: 'OPERATING_RESULT', amount: 50, date: Time.zone.local(2026, 2, 10, 12, 0, 0))
    # Fee por retiro el 15 feb (cobra sobre esos 50)
    TradingFee.create!(
      investor: investor,
      applied_by: user,
      period_start: Date.new(2026, 2, 15),
      period_end: Date.new(2026, 2, 16),
      profit_amount: 50,
      fee_percentage: 30,
      fee_amount: 15,
      source: 'WITHDRAWAL',
      withdrawal_amount: 20,
      withdrawal_request_id: wd_req.id,
      applied_at: Time.zone.local(2026, 2, 15, 14, 0, 0)
    )
    # Operativa feb 16-28
    make_history(event: 'OPERATING_RESULT', amount: 30, date: Time.zone.local(2026, 2, 20, 12, 0, 0))

    calc = described_class.new(investor, reference_date: Date.new(2026, 3, 5))
    result = calc.calculate

    # Período debe ser 16 feb - 28 feb (no 1-28, porque el fee por retiro ya cobró 1-15)
    expect(result[:period_start]).to eq(Date.new(2026, 2, 16))
    expect(result[:period_end]).to eq(Date.new(2026, 2, 28))
    expect(result[:profit_amount]).to eq(30.0)
  end
end
