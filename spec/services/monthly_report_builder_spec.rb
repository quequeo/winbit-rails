# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MonthlyReportBuilder do
  let(:investor) do
    Investor.create!(email: 'eugenio.carrio7@gmail.com', name: 'Eugenio Carrió', status: 'ACTIVE')
  end

  let!(:portfolio) do
    Portfolio.create!(
      investor: investor,
      current_balance: 6750.04,
      strategy_return_all_usd: 2322.75,
      strategy_return_all_percent: 42.21,
      strategy_return_ytd_usd: 323.75,
      strategy_return_ytd_percent: 5.3643,
    )
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
  end

  describe 'report for April 2026 (spreadsheet only)' do
    before do
      portfolio.update!(strategy_return_ytd_usd: 440, strategy_return_ytd_percent: 7.28)
    end

    it 'returns annex rows and summary from imported data' do
      report = described_class.new(investor: investor, report_month: Date.new(2026, 4, 1)).build

      expect(report[:report_month]).to eq('2026-04')
      expect(report[:annex_rows].size).to eq(5)
      expect(report[:summary][:portfolio_value_usd]).to eq(6484.0)
      expect(report[:summary][:accumulated_2026_usd]).to eq(440.0)
      expect(report[:summary][:accumulated_since_entry_usd]).to eq(2322.75)
    end
  end

  describe 'report for May 2026 (platform month)' do
    let(:may_start) { Time.zone.local(2026, 5, 1, 0, 0, 0) }
    let(:may_deposit_time) { Time.zone.local(2026, 5, 19, 12, 0, 0) }

    before do
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
        date: may_deposit_time,
        status: 'COMPLETED',
      )

      DailyOperatingResult.create!(
        date: Date.new(2026, 5, 15),
        percent: -1.78,
        applied_at: Time.zone.local(2026, 5, 15, 19, 0, 0),
        applied_by: User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '1'),
      )
    end

    it 'appends May row from platform excluding genesis batch flows' do
      travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
        report = described_class.new(investor: investor, report_month: Date.new(2026, 5, 1)).build
        may_row = report[:annex_rows].find { |r| r[:month] == '2026-05' }

        expect(may_row).to be_present
        expect(may_row[:source]).to eq('platform')
        expect(may_row[:deposits]).to eq(382.29)
        expect(may_row[:return_usd]).to be_within(0.01).of(-116.25)
        expect(may_row[:return_percent]).to be_within(0.05).of(-1.79)
        expect(may_row[:portfolio_value]).to eq(6750.04)
        expect(report[:summary][:winbit_monthly_return_percent]).to eq(-1.78)
        expect(report[:summary][:accumulated_2026_usd]).to be_within(0.01).of(323.75)
        expect(report[:summary][:accumulated_2026_percent]).to be_within(0.05).of(5.36)
      end
    end

    it 'ignores genesis operating result lump in May return usd' do
      PortfolioHistory.delete_all
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
        amount: 2322.75,
        previous_balance: 6484,
        new_balance: 8806.75,
        date: Time.zone.local(2026, 5, 2, 19, 0, 0),
        status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: -2439.0,
        previous_balance: 8806.75,
        new_balance: 6367.75,
        date: Time.zone.local(2026, 5, 18, 19, 0, 0),
        status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 382.29,
        previous_balance: 6367.75,
        new_balance: 6750.04,
        date: may_deposit_time,
        status: 'COMPLETED',
      )

      travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
        report = described_class.new(investor: investor, report_month: Date.new(2026, 5, 1)).build
        may_row = report[:annex_rows].find { |r| r[:month] == '2026-05' }

        expect(may_row[:return_usd]).to be_within(0.01).of(-116.25)
        expect(report[:summary][:accumulated_2026_usd]).to be_within(0.01).of(323.75)
      end
    end
  end
end

RSpec.describe MonthlyReportBuilder do
  describe 'summary matches investor dashboard payload' do
    let(:investor) do
      Investor.create!(email: 'dash@test.com', name: 'Dash Test', status: 'ACTIVE')
    end

    before do
      Portfolio.create!(
        investor: investor,
        current_balance: 1828.74,
        strategy_return_ytd_usd: 92.74,
        strategy_return_ytd_percent: 6.8321,
        strategy_return_all_usd: 328.74,
        strategy_return_all_percent: 21.9167,
      )
    end

    it 'uses the same strategy return fields as the investor panel' do
      travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
        report = described_class.new(investor: investor, report_month: Date.new(2026, 5, 1)).build
        dashboard = InvestorPortfolioDashboardPayload.build(investor: investor)

        expect(report[:summary][:portfolio_value_usd]).to eq(dashboard[:currentBalance])
        expect(report[:summary][:accumulated_since_entry_usd]).to eq(dashboard[:strategyReturnAllUSD])
        expect(report[:summary][:accumulated_since_entry_percent]).to eq(dashboard[:strategyReturnAllPercent])
        expect(report[:summary][:accumulated_2026_usd]).to eq(dashboard[:strategyReturnYtdUSD])
        expect(report[:summary][:accumulated_2026_percent]).to eq(dashboard[:strategyReturnYtdPercent])
      end
    end
  end
end

RSpec.describe MonthlyReportBuilder do
  describe 'Agustina — YTD net of CST (spreadsheet months)' do
    let(:investor) do
      Investor.create!(email: 'aguslancia@gmail.com', name: 'Agustina Lancia', status: 'ACTIVE')
    end

    before do
      Portfolio.create!(
        investor: investor,
        current_balance: 2871,
        strategy_return_ytd_usd: 107.72,
        strategy_return_ytd_percent: 3.9724,
      )
      [
        [Date.new(2025, 12, 1), nil, nil, 0, 0, 0, 2712, true],
        [Date.new(2026, 1, 1), 0, 0, 0, 0, 0, 2712, false],
        [Date.new(2026, 2, 1), 2, 63, 0, 0, 0, 2775, false],
        [Date.new(2026, 3, 1), 2.3, 64, 0, 0, 38, 2801, false],
        [Date.new(2026, 4, 1), 2.5, 70, 0, 0, 0, 2871, false],
      ].each do |month, pct, usd, dep, wdr, cst, value, opening|
        InvestorMonthlyAnnexRow.create!(
          investor: investor,
          month: month,
          return_percent: pct,
          return_usd: usd,
          deposits: dep,
          withdrawals: wdr,
          service_cost: cst,
          portfolio_value: value,
          opening_snapshot: opening,
          source: 'spreadsheet',
        )
      end
    end

    it 'uses dashboard strategy return fields for accumulated 2026' do
      report = described_class.new(investor: investor, report_month: Date.new(2026, 4, 1)).build
      dashboard = InvestorPortfolioDashboardPayload.build(investor: investor)

      expect(report[:summary][:accumulated_2026_usd]).to eq(dashboard[:strategyReturnYtdUSD])
      expect(report[:summary][:accumulated_2026_percent]).to eq(dashboard[:strategyReturnYtdPercent])
    end
  end
end

RSpec.describe MonthlyReportBuilder do
  describe 'report for entry investor (INGRESO row)' do
    let(:investor) do
      Investor.create!(email: 'jaimegarciamendez@gmail.com', name: 'Jaime García Mendez', status: 'ACTIVE')
    end

    let!(:portfolio) do
      Portfolio.create!(investor: investor, current_balance: 2776, strategy_return_all_usd: -24, strategy_return_all_percent: -4.8)
    end

    before do
      InvestorMonthlyAnnexRow.create!(
        investor: investor,
        month: Date.new(2026, 4, 1),
        portfolio_value: 500,
        opening_snapshot: true,
        entry_row: true,
        source: 'spreadsheet',
      )
    end

    it 'includes INGRESO row and uses entry balance as YTD base' do
      travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
        report = described_class.new(investor: investor, report_month: Date.new(2026, 5, 1)).build
        ingreso = report[:annex_rows].find { |r| r[:entry_row] }

        expect(ingreso).to be_present
        expect(ingreso[:label]).to eq('INGRESO')
        expect(ingreso[:portfolio_value]).to eq(500.0)
        expect(report[:annex_rows].map { |r| r[:label] }).to include('May-26')
      end
    end
  end
end
