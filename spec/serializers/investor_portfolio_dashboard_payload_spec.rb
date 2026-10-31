# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorPortfolioDashboardPayload do
  let(:investor) { Investor.create!(email: 'dashboard-payload@test.com', name: 'Lia', status: 'ACTIVE', trading_fee_percentage: 25) }

  around { |example| travel_to(Time.zone.parse('2026-10-31 12:00:00')) { example.run } }

  def create_fee(amount:, previous_balance:, date:)
    PortfolioHistory.create!(
      investor: investor, event: 'TRADING_FEE', amount: -amount,
      previous_balance: previous_balance, new_balance: previous_balance - amount,
      status: 'COMPLETED', date: Time.zone.parse(date),
    )
  end

  # Lía Ana Vigo's real numbers on 2026-09-16: joined via the Genesis snapshot,
  # one service charge ($49.94, 2026-06-30), never withdrew.
  it 'nets the service cost out of both the YTD and all-time strategy return' do
    Portfolio.create!(
      investor: investor,
      current_balance: 8903.84,
      total_invested: 7923,
      accumulated_return_usd: 980.84,
      accumulated_return_percent: 12.3797,
      strategy_return_ytd_usd: 585.78,
      strategy_return_ytd_percent: 7.0073,
      strategy_return_all_usd: 1030.78,
      strategy_return_all_percent: 13.0173,
    )
    create_fee(amount: 49.94, previous_balance: 8860.76, date: '2026-06-30 17:00:00')

    payload = described_class.build(investor: investor)

    expect(payload[:strategyReturnYtdNetUSD]).to eq(535.84)
    expect(payload[:strategyReturnYtdNetPercent]).to be_within(0.01).of(6.41)
    expect(payload[:strategyReturnAllNetUSD]).to eq(980.84)
    expect(payload[:strategyReturnAllNetPercent]).to be_within(0.01).of(12.39)
    expect(payload[:strategyReturnYtdUSD]).to eq(585.78)
  end

  it 'only nets the fees charged this year out of the YTD figure' do
    Portfolio.create!(
      investor: investor, current_balance: 11_000, total_invested: 10_000,
      strategy_return_ytd_usd: 600, strategy_return_ytd_percent: 6.0,
      strategy_return_all_usd: 1100, strategy_return_all_percent: 11.0,
    )
    create_fee(amount: 40, previous_balance: 10_440, date: '2025-12-31 17:00:00')
    create_fee(amount: 60, previous_balance: 11_060, date: '2026-09-30 17:00:00')

    payload = described_class.build(investor: investor)

    expect(payload[:strategyReturnYtdNetUSD]).to eq(540.0)
    expect(payload[:strategyReturnAllNetUSD]).to eq(1000.0)
  end

  it 'equals the gross figures when no service cost was ever charged' do
    Portfolio.create!(
      investor: investor, current_balance: 11_000, total_invested: 10_000,
      strategy_return_ytd_usd: 1000, strategy_return_ytd_percent: 10.0,
      strategy_return_all_usd: 1000, strategy_return_all_percent: 10.0,
    )

    payload = described_class.build(investor: investor)

    expect(payload[:strategyReturnYtdNetUSD]).to eq(1000.0)
    expect(payload[:strategyReturnYtdNetPercent]).to eq(10.0)
    expect(payload[:strategyReturnAllNetUSD]).to eq(1000.0)
    expect(payload[:strategyReturnAllNetPercent]).to eq(10.0)
  end

  it 'does not net the fee twice when the figures come from the TWR calculator' do
    Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000)
    create_fee(amount: 50, previous_balance: 1050, date: '2026-09-30 17:00:00')
    twr = Struct.new(:pnl_usd, :twr_percent, :effective_start_at).new(50.0, 5.0, nil)
    allow(TimeWeightedReturnCalculator).to receive(:for_investor).and_return(twr)

    payload = described_class.build(investor: investor)

    expect(payload[:strategyReturnYtdNetUSD]).to eq(50.0)
    expect(payload[:strategyReturnAllNetUSD]).to eq(50.0)
  end

  it 'shows exactly the figures of the current month report (the PDF), all net of the service cost' do
    Portfolio.create!(
      investor: investor, current_balance: 11_040, total_invested: 10_000,
      strategy_return_ytd_usd: 1100, strategy_return_ytd_percent: 11.0,
      strategy_return_all_usd: 1100, strategy_return_all_percent: 11.0,
    )
    PortfolioHistory.create!(
      investor: investor, event: 'DEPOSIT', amount: 10_000, previous_balance: 0, new_balance: 10_000,
      status: 'COMPLETED', date: Time.zone.parse('2026-05-04 12:00:00'),
    )
    PortfolioHistory.create!(
      investor: investor, event: 'OPERATING_RESULT', amount: 1000, previous_balance: 10_000, new_balance: 11_000,
      status: 'COMPLETED', date: Time.zone.parse('2026-09-15 17:00:00'),
    )
    create_fee(amount: 60, previous_balance: 11_000, date: '2026-09-30 17:00:00')
    PortfolioHistory.create!(
      investor: investor, event: 'OPERATING_RESULT', amount: 100, previous_balance: 10_940, new_balance: 11_040,
      status: 'COMPLETED', date: Time.zone.parse('2026-10-20 17:00:00'),
    )

    payload = described_class.build(investor: investor)
    report = MonthlyReportBuilder.new(investor: investor, report_month: Date.new(2026, 10, 1)).build

    expect(payload[:netContributedUSD]).to eq(10_000.0)
    expect(payload[:monthReturnNetUSD]).to eq(report[:month_row][:return_usd])
    expect(payload[:monthReturnNetPercent]).to eq(report[:month_row][:return_percent])
    expect(payload[:strategyReturnYtdNetUSD]).to eq(report[:summary][:accumulated_2026_usd])
    expect(payload[:strategyReturnAllNetUSD]).to eq(report[:summary][:accumulated_since_entry_usd])
    expect(payload[:monthReturnNetUSD]).to eq(100.0)
    expect(payload[:strategyReturnYtdNetUSD]).to eq(1040.0)
  end

  it 'returns nil when the investor has no portfolio' do
    expect(described_class.build(investor: investor)).to be_nil
  end
end
