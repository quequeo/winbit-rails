# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MonthlyOperationsReport do
  let!(:admin) { User.create!(email: 'admin-mor@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'mor-1') }

  before do
    DailyOperatingResult.create!(date: Date.new(2026, 6, 15), percent: 1.5, applied_at: Time.zone.local(2026, 6, 15, 19, 0, 0), applied_by: admin)

    [
      [Date.new(2026, 6, 2), 'MNQ', 'LONG', '10:22', '10:41', 44, 0.90],
      [Date.new(2026, 6, 15), 'MES', 'SHORT', '11:08', '11:24', -45, -1.00],
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
      result_usd: 10, ratio: 1.0, source: 'manual', result_label: 'POSITIVO', created_by: admin
    )
  end

  it 'builds trades, asset chips and summary stats for the given month' do
    result = described_class.call(month: '2026-06')

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
    expect(mes_trade.result_percent).to eq(1.5)
    expect(mes_trade.ratio).to eq(-1.0)
  end

  it 'accepts a Date for month' do
    result = described_class.call(month: Date.new(2026, 6, 1))
    expect(result.count).to eq(3)
  end
end
