# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MonthlyOperationsReport do
  let!(:admin) { User.create!(email: 'admin-mor@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'mor-1') }
  let!(:investor) { Investor.create!(email: 'mor-investor@example.com', name: 'MOR Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000) }

  before do
    DailyOperatingResult.create!(date: Date.new(2026, 6, 15), percent: 1.5, applied_at: Time.zone.local(2026, 6, 15, 19, 0, 0), applied_by: admin)

    # Firm-wide trades (identity/metadata only - dollar result is per-investor).
    [
      [Date.new(2026, 6, 2), 'MNQ', 'LONG', '10:22', '10:41', 4400, 0.90],
      [Date.new(2026, 6, 15), 'MES', 'SHORT', '11:08', '11:24', -4500, -1.00],
      [Date.new(2026, 6, 20), 'MYM', 'LONG', '10:36', '11:02', 0, 0.0],
    ].each do |date, asset, direction, opened_at, closed_at, result_usd, ratio|
      StrategyOperation.create!(
        operation_date: date, asset: asset, direction: direction, opened_at: opened_at, closed_at: closed_at,
        result_usd: result_usd, ratio: ratio, source: 'manual',
        result_label: result_usd.positive? ? 'POSITIVO' : (result_usd.negative? ? 'NEGATIVO' : 'BE+'),
        created_by: admin
      )
    end

    # Outside the queried month - must not leak in.
    StrategyOperation.create!(
      operation_date: Date.new(2026, 7, 1), asset: 'MBT', direction: 'LONG', opened_at: '10:00', closed_at: '10:10',
      result_usd: 1000, ratio: 1.0, source: 'manual', result_label: 'POSITIVO', created_by: admin
    )

    # This investor's own dollar result each day - distinct from the firm-level
    # StrategyOperation.result_usd above, proving the report uses this source.
    [
      [Date.new(2026, 6, 2), 44],
      [Date.new(2026, 6, 15), -45],
      [Date.new(2026, 6, 20), 0],
    ].each do |date, amount|
      PortfolioHistory.create!(
        investor: investor, event: 'OPERATING_RESULT', amount: amount,
        previous_balance: 1000, new_balance: 1000 + amount,
        date: Time.zone.local(date.year, date.month, date.day, 19, 0, 0), status: 'COMPLETED'
      )
    end
  end

  it "builds trades from the investor's own daily results, not the firm-wide trade amount" do
    result = described_class.call(investor: investor, month: '2026-06')

    expect(result.trades.size).to eq(3)
    expect(result.count).to eq(3)
    expect(result.positive).to eq(1)
    expect(result.negative).to eq(1)
    expect(result.break_even).to eq(1)
    expect(result.net_result_usd).to eq(-1.0)

    expect(result.assets).to contain_exactly(
      { code: 'MNQ', name: 'Micro E-mini Nasdaq-100' },
      { code: 'MES', name: 'Micro E-mini S&P 500' },
      { code: 'MYM', name: 'Micro E-mini Dow Jones' },
    )

    mes_trade = result.trades.find { |t| t.asset == 'MES' }
    expect(mes_trade.result_usd).to eq(-45.0)
    expect(mes_trade.result_percent).to eq(1.5)
    expect(mes_trade.ratio).to eq(-1.0)
  end

  it 'accepts a Date for month' do
    result = described_class.call(investor: investor, month: Date.new(2026, 6, 1))
    expect(result.count).to eq(3)
  end

  it 'only includes dates the investor actually has an operating result for (mid-month entry)' do
    late_investor = Investor.create!(email: 'late-mor@example.com', name: 'Late Joiner', status: 'ACTIVE')
    Portfolio.create!(investor: late_investor, current_balance: 500, total_invested: 500)
    PortfolioHistory.create!(
      investor: late_investor, event: 'OPERATING_RESULT', amount: 0,
      previous_balance: 500, new_balance: 500,
      date: Time.zone.local(2026, 6, 20, 19, 0, 0), status: 'COMPLETED'
    )

    result = described_class.call(investor: late_investor, month: '2026-06')

    expect(result.trades.map(&:date)).to eq([Date.new(2026, 6, 20)])
  end

  it "classifies by the trade's result_label, not the sign of this investor's own $ amount" do
    # A trade the system calls break-even can still net a small negative $
    # for a given investor (proportional CST/rounding) - that must still
    # count as break-even, not a loss.
    StrategyOperation.create!(
      operation_date: Date.new(2026, 6, 27), asset: 'MBT', direction: 'LONG', opened_at: '10:00', closed_at: '10:05',
      result_usd: -12.0, ratio: 0.0, source: 'manual', result_label: 'BE-', created_by: admin
    )
    PortfolioHistory.create!(
      investor: investor, event: 'OPERATING_RESULT', amount: -3.5,
      previous_balance: 1000, new_balance: 996.5,
      date: Time.zone.local(2026, 6, 27, 19, 0, 0), status: 'COMPLETED'
    )

    result = described_class.call(investor: investor, month: '2026-06')

    be_trade = result.trades.find { |t| t.date == Date.new(2026, 6, 27) }
    expect(be_trade.result_usd).to eq(-3.5)
    expect(be_trade.result_label).to eq('BE-')
    expect(result.break_even).to eq(2)
    expect(result.negative).to eq(1)
  end

  it 'includes an operating result on the last day of the month (not just midnight)' do
    # date.end_of_month is a bare Date (midnight) - using it as a range end
    # against a datetime column silently excludes anything later that day,
    # e.g. the usual 19:00 daily-close timestamp on the month's last day.
    StrategyOperation.create!(
      operation_date: Date.new(2026, 6, 30), asset: 'MBT', direction: 'LONG', opened_at: '10:00', closed_at: '10:05',
      result_usd: 20.0, ratio: 1.0, source: 'manual', result_label: 'POSITIVO', created_by: admin
    )
    PortfolioHistory.create!(
      investor: investor, event: 'OPERATING_RESULT', amount: 12.0,
      previous_balance: 1000, new_balance: 1012.0,
      date: Time.zone.local(2026, 6, 30, 19, 0, 0), status: 'COMPLETED'
    )

    result = described_class.call(investor: investor, month: '2026-06')

    expect(result.trades.map(&:date)).to include(Date.new(2026, 6, 30))
    expect(result.count).to eq(4)
  end

  it 'skips a day with no matching firm-wide trade instead of erroring' do
    PortfolioHistory.create!(
      investor: investor, event: 'OPERATING_RESULT', amount: 5,
      previous_balance: 1000, new_balance: 1005,
      date: Time.zone.local(2026, 6, 25, 19, 0, 0), status: 'COMPLETED'
    )

    result = described_class.call(investor: investor, month: '2026-06')

    expect(result.trades.map(&:date)).not_to include(Date.new(2026, 6, 25))
    expect(result.count).to eq(3)
  end
end
