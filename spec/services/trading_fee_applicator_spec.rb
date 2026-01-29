require 'rails_helper'

RSpec.describe TradingFeeApplicator do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '123') }
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 1100, total_invested: 1000) }

  def add_history(event:, amount:, date:, prev:, newb:)
    PortfolioHistory.create!(
      investor: investor,
      event: event,
      amount: amount,
      previous_balance: prev,
      new_balance: newb,
      status: 'COMPLETED',
      date: date,
    )
  end

  it 'applies trading fee for an overridden period and updates portfolio + creates history' do
    start_date = Date.new(2025, 10, 1)
    end_date = Date.new(2025, 12, 31)

    add_history(event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2025, 10, 1, 19, 0, 0), prev: 0, newb: 1000)
    add_history(event: 'OPERATING_RESULT', amount: 100, date: Time.zone.local(2025, 11, 15, 17, 0, 0), prev: 1000, newb: 1100)

    applicator = described_class.new(
      investor,
      fee_percentage: 30,
      applied_by: admin,
      notes: 'test',
      period_start: start_date,
      period_end: end_date,
    )

    expect(applicator.apply).to eq(true)

    fee = TradingFee.find_by!(investor_id: investor.id, period_start: start_date, period_end: end_date)
    expect(fee.profit_amount.to_f).to eq(100.0)
    expect(fee.fee_percentage.to_f).to eq(30.0)
    expect(fee.fee_amount.to_f).to eq(30.0)

    investor.reload
    expect(investor.portfolio.current_balance.to_f).to eq(1070.0)

    last = PortfolioHistory.where(investor_id: investor.id, event: 'TRADING_FEE').order(date: :desc).first
    expect(last).to be_present
    expect(last.amount.to_f).to eq(-30.0)
  end

  it 'fails when profit is <= 0' do
    applicator = described_class.new(
      investor,
      fee_percentage: 30,
      applied_by: admin,
      period_start: Date.new(2025, 10, 1),
      period_end: Date.new(2025, 12, 31),
    )

    expect(applicator.apply).to eq(false)
    expect(applicator.errors.join(' ')).to include('No profit')
  end

  it 'fails on duplicate fee for the same period' do
    start_date = Date.new(2025, 10, 1)
    end_date = Date.new(2025, 12, 31)

    TradingFee.create!(
      investor: investor,
      applied_by: admin,
      period_start: start_date,
      period_end: end_date,
      profit_amount: 100,
      fee_percentage: 30,
      fee_amount: 30,
      applied_at: Time.current,
    )

    add_history(event: 'OPERATING_RESULT', amount: 100, date: Time.zone.local(2025, 11, 15, 17, 0, 0), prev: 1000, newb: 1100)

    applicator = described_class.new(
      investor,
      fee_percentage: 30,
      applied_by: admin,
      period_start: start_date,
      period_end: end_date,
    )

    expect(applicator.apply).to eq(false)
    expect(applicator.errors.join(' ')).to include('ya aplicado')
  end

  it 'rejects non-annual period when investor is ANNUAL' do
    investor.update!(trading_fee_frequency: 'ANNUAL')

    applicator = described_class.new(
      investor,
      fee_percentage: 30,
      applied_by: admin,
      period_start: Date.new(2025, 10, 1),
      period_end: Date.new(2025, 12, 31),
    )

    expect(applicator.apply).to eq(false)
    expect(applicator.errors.join(' ')).to include('ANNUAL')
  end
end
