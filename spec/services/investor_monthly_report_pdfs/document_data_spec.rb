# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::DocumentData do
  let(:investor) do
    Investor.create!(email: 'camilo.giordano@example.com', name: 'Camilo Giordano', status: 'ACTIVE')
  end

  let!(:portfolio) do
    Portfolio.create!(
      investor: investor,
      current_balance: 6750.04,
      total_invested: 6484,
      strategy_return_all_usd: 2322.75,
      strategy_return_all_percent: 42.21,
      strategy_return_ytd_usd: 323.75,
      strategy_return_ytd_percent: 5.3643,
    )
  end

  let!(:admin) do
    User.create!(email: 'admin-doc-data@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'doc-data-1')
  end

  before do
    [
      [Date.new(2025, 12, 1), nil, nil, 6044, true],
      [Date.new(2026, 1, 1), 0, -1, 6043, false],
      [Date.new(2026, 2, 1), 2, 140, 6183, false],
      [Date.new(2026, 3, 1), 2.3, 143, 6325, false],
      [Date.new(2026, 4, 1), 2.5, 158, 6484, false],
    ].each do |month, pct, usd, value, opening|
      InvestorMonthlyAnnexRow.create!(
        investor: investor,
        month: month,
        return_percent: pct,
        return_usd: usd,
        portfolio_value: value,
        opening_snapshot: opening,
        source: 'spreadsheet',
      )
    end

    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 6484,
      previous_balance: 0,
      new_balance: 6484,
      date: Time.zone.local(2026, 5, 1, 19, 0, 0),
      status: 'COMPLETED',
    )
    PortfolioHistory.create!(
      investor: investor,
      event: 'OPERATING_RESULT',
      amount: -116.25,
      previous_balance: 6484,
      new_balance: 6367.75,
      date: Time.zone.local(2026, 5, 2, 19, 0, 0),
      status: 'COMPLETED',
    )
    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 382.29,
      previous_balance: 6367.75,
      new_balance: 6750.04,
      date: Time.zone.local(2026, 5, 19, 12, 0, 0),
      status: 'COMPLETED',
    )
    DailyOperatingResult.create!(
      date: Date.new(2026, 5, 15),
      percent: -1.78,
      applied_at: Time.zone.local(2026, 5, 15, 19, 0, 0),
      applied_by: admin,
    )

    [
      [Date.new(2026, 5, 2), 'MNQ', 'LONG', '10:22', '10:41', 44, 0.90],
      [Date.new(2026, 5, 15), 'MES', 'SHORT', '11:08', '11:24', -45, -1.00],
    ].each do |date, asset, direction, opened_at, closed_at, result_usd, ratio|
      StrategyOperation.create!(
        operation_date: date,
        asset: asset,
        direction: direction,
        opened_at: opened_at,
        closed_at: closed_at,
        result_usd: result_usd,
        ratio: ratio,
        source: 'manual',
        result_label: result_usd.positive? ? 'POSITIVO' : 'NEGATIVO',
        created_by: admin,
      )
    end

    # The investor's own daily result is what actually drives which trades
    # show up (see MonthlyOperationsReport) - May 2 already exists above
    # (negative), this one is positive so the spec covers both signs.
    PortfolioHistory.create!(
      investor: investor, event: 'OPERATING_RESULT', amount: 45,
      previous_balance: 6367.75, new_balance: 6412.75,
      date: Time.zone.local(2026, 5, 15, 19, 0, 0), status: 'COMPLETED',
    )
  end

  it 'builds the full data hash consumed by the PDF template' do
    travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
      data = described_class.call(investor: investor, report_month: '2026-05')

      expect(data[:investor_name]).to eq('Camilo Giordano')
      expect(data[:month_label]).to eq('MAYO 2026')
      expect(data[:portfolio_value]).to eq('6.750')
      expect(data[:net_contributed]).to eq('6.484')
      expect(data[:year_opening][:date]).to eq('01/01/2026')
      expect(data[:year_opening][:value]).to eq('6.044')

      expect(data[:evo_rows].size).to eq(5)
      expect(data[:evo_rows].last[:label]).to eq('May-26')
      expect(data[:evo_rows].last[:last]).to be(true)

      expect(data[:chart_svg]).to include('<svg')

      expect(data[:ops_pages].size).to eq(1)
      page = data[:ops_pages].first
      expect(page[:trades].size).to eq(2)
      expect(page[:assets]).to contain_exactly(
        { code: 'MNQ', name: 'Micro E-mini Nasdaq-100' },
        { code: 'MES', name: 'Micro E-mini S&P 500' },
      )
      expect(page[:ops_summary][:count]).to eq(2)
      expect(page[:ops_summary][:positive]).to eq(1)
      expect(page[:ops_summary][:negative]).to eq(1)
    end
  end

  it 'paginates trades beyond OPS_PAGE_LIMIT rows per page' do
    # Days 3-20 (18 new trades) plus the existing May 2 and May 15 trades
    # from the outer `before` block = 20 total.
    (3..20).each do |day|
      date = Date.new(2026, 5, day)
      StrategyOperation.create!(
        operation_date: date,
        asset: 'MYM',
        direction: 'LONG',
        opened_at: '10:00',
        closed_at: '10:15',
        result_usd: 10,
        ratio: 1.0,
        source: 'manual',
        result_label: 'POSITIVO',
        created_by: admin,
      )
      PortfolioHistory.create!(
        investor: investor, event: 'OPERATING_RESULT', amount: 10,
        previous_balance: 6484, new_balance: 6494,
        date: Time.zone.local(2026, 5, day, 19, 0, 0), status: 'COMPLETED',
      )
    end

    travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
      data = described_class.call(investor: investor, report_month: '2026-05')

      expect(data[:ops_pages].size).to eq(2)
      expect(data[:ops_pages].first[:trades].size).to eq(described_class::OPS_PAGE_LIMIT)
      expect(data[:ops_pages].first[:last]).to be(false)
      expect(data[:ops_pages].last[:last]).to be(true)
      expect(data[:ops_pages].last[:ops_summary]).to be_present
    end
  end
end
