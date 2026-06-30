require 'rails_helper'

RSpec.describe TradingFeeCalculator do
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0) }

  def make_history(event:, amount:, date:, prev: nil, newb: nil)
    prev ||= portfolio.current_balance
    newb ||= prev + amount

    PortfolioHistory.create!(
      investor: investor,
      event: event,
      amount: amount,
      previous_balance: prev,
      new_balance: newb,
      status: 'COMPLETED',
      date: date,
    )

    portfolio.update!(current_balance: newb)

    if event == 'DEPOSIT'
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        amount: amount,
        method: 'USDT',
        status: 'APPROVED',
        requested_at: date,
        processed_at: date
      )
    end
  end

  it 'returns last completed quarter range based on reference_date' do
    # reference_date in Q1 2026 -> last completed quarter is Q4 2025
    calc = described_class.new(investor, reference_date: Date.new(2026, 1, 21))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2025, 10, 1))
    expect(result[:period_end]).to eq(Date.new(2025, 12, 31))
  end

  it 'returns current quarter on the last day of the quarter (Q2 on 30 Jun)' do
    make_history(event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2026, 4, 1, 19, 0, 0))
    make_history(event: 'OPERATING_RESULT', amount: 40, date: Time.zone.local(2026, 6, 15, 17, 0, 0), prev: 1000, newb: 1040)

    calc = described_class.new(investor, reference_date: Date.new(2026, 6, 30))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2026, 4, 1))
    expect(result[:period_end]).to eq(Date.new(2026, 6, 30))
    expect(result[:profit_amount]).to eq(40.0)
    expect(result[:vpcust_usd]).to eq(0.0)
    expect(result[:inflows_usd]).to eq(1000.0)
  end

  it 'returns previous quarter before the quarter last day' do
    calc = described_class.new(investor, reference_date: Date.new(2026, 6, 29))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2026, 1, 1))
    expect(result[:period_end]).to eq(Date.new(2026, 3, 31))
  end

  it 'uses Vpcust basis for profit (CAP ACT − VPCUST − INGRESOS)' do
    make_history(event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2025, 10, 1, 19, 0, 0))
    make_history(event: 'OPERATING_RESULT', amount: 10, date: Time.zone.local(2025, 10, 10, 12, 0, 0), prev: 1000, newb: 1010)
    make_history(event: 'OPERATING_RESULT', amount: 5, date: Time.zone.local(2025, 12, 31, 16, 0, 0), prev: 1010, newb: 1015)

    calc = described_class.new(investor, reference_date: Date.new(2026, 1, 21))
    result = calc.calculate

    expect(result[:profit_amount]).to eq(15.0)
    expect(result[:vpcust_usd]).to eq(0.0)
    expect(result[:inflows_usd]).to eq(1000.0)
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

  it 'uses full calendar period when withdrawal fee was charged mid-month (profit via Vpcust)' do
    investor.update!(trading_fee_frequency: 'MONTHLY')
    user = User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '1')
    wd_req = InvestorRequest.create!(investor: investor, request_type: 'WITHDRAWAL', amount: 20, method: 'USDT', status: 'APPROVED')

    make_history(event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2026, 2, 1, 19, 0, 0))
    make_history(event: 'OPERATING_RESULT', amount: 50, date: Time.zone.local(2026, 2, 10, 12, 0, 0), prev: 1000, newb: 1050)
    make_history(event: 'TRADING_FEE', amount: -15, date: Time.zone.local(2026, 2, 15, 14, 0, 0), prev: 1050, newb: 1035)
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
    make_history(event: 'WITHDRAWAL', amount: 20, date: Time.zone.local(2026, 2, 15, 15, 0, 0), prev: 1035, newb: 1015)
    make_history(event: 'OPERATING_RESULT', amount: 30, date: Time.zone.local(2026, 2, 20, 12, 0, 0), prev: 1015, newb: 1045)

    calc = described_class.new(investor, reference_date: Date.new(2026, 3, 5))
    result = calc.calculate

    expect(result[:period_start]).to eq(Date.new(2026, 2, 1))
    expect(result[:period_end]).to eq(Date.new(2026, 2, 28))
    expect(result[:profit_amount]).to eq(30.0)
  end
end
