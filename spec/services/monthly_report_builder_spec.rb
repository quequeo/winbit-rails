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

    it 'reports gross RDO M when CST was charged in the month' do
      PortfolioHistory.create!(
        investor: investor,
        event: 'TRADING_FEE',
        amount: -30,
        previous_balance: 6750.04,
        new_balance: 6720.04,
        date: Time.zone.local(2026, 5, 28, 19, 0, 0),
        status: 'COMPLETED',
      )

      travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
        report = described_class.new(investor: investor, report_month: Date.new(2026, 5, 1)).build
        may_row = report[:annex_rows].find { |r| r[:month] == '2026-05' }

        expect(may_row[:service_cost]).to eq(30.0)
        expect(may_row[:return_usd]).to be_within(0.01).of(-116.25)
        expect(may_row[:return_usd]).not_to be_within(0.01).of(-146.25)
        expect(may_row[:return_percent]).to be_within(0.05).of(-1.79)
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
  describe 'summary lifetime fields match investor dashboard payload' do
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
      InvestorMonthlyAnnexRow.create!(
        investor: investor,
        month: Date.new(2025, 12, 1),
        portfolio_value: 1500,
        opening_snapshot: true,
        entry_row: true,
        source: 'spreadsheet',
      )
    end

    it 'uses panel strategy_return_all for since-entry and panel strategy_return_ytd (TWR) for 2026 YTD' do
      travel_to Time.zone.local(2026, 5, 29, 12, 0, 0) do
        PortfolioHistory.create!(
          investor: investor,
          event: 'DEPOSIT',
          amount: 1500,
          previous_balance: 0,
          new_balance: 1500,
          date: Time.zone.local(2026, 5, 1, 19, 0, 0),
          status: 'COMPLETED',
        )
        PortfolioHistory.create!(
          investor: investor,
          event: 'OPERATING_RESULT',
          amount: 328.74,
          previous_balance: 1500,
          new_balance: 1828.74,
          date: Time.zone.local(2026, 5, 20, 19, 0, 0),
          status: 'COMPLETED',
        )

        report = described_class.new(investor: investor, report_month: Date.new(2026, 5, 1)).build
        dashboard = InvestorPortfolioDashboardPayload.build(investor: investor)

        expect(report[:summary][:portfolio_value_usd]).to eq(dashboard[:currentBalance])
        expect(report[:summary][:accumulated_since_entry_usd]).to eq(dashboard[:strategyReturnAllUSD])
        expect(report[:summary][:accumulated_since_entry_percent]).to eq(dashboard[:strategyReturnAllPercent])
        # TWR-based (panel strategy_return_ytd_*), not the annex/RDO sum - robust
        # to large interim withdrawals (see Requests::Approve / Luis Matías Crocci case).
        expect(report[:summary][:accumulated_2026_usd]).to eq(dashboard[:strategyReturnYtdUSD])
        expect(report[:summary][:accumulated_2026_usd]).to eq(92.74)
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

    it 'uses the panel TWR-based YTD (not the annex/gross RDO sum, which understates return under withdrawals)' do
      report = described_class.new(investor: investor, report_month: Date.new(2026, 4, 1)).build
      data_rows = report[:annex_rows].reject { |r| r[:opening_snapshot] || r[:entry_row] }
      gross = data_rows.sum { |r| r[:return_usd].to_f }
      cst = data_rows.sum { |r| r[:service_cost].to_f }

      expect(gross).to eq(197.0)
      expect(cst).to eq(38.0)
      expect(report[:summary][:accumulated_2026_usd]).to eq(107.72)
      expect(report[:summary][:accumulated_2026_percent]).to be_within(0.01).of(3.9724)
      expect(report[:summary][:accumulated_2026_usd]).not_to eq(gross - cst)
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

RSpec.describe MonthlyReportBuilder do
  describe 'current month includes today operativa stamped at 17:00' do
    let(:investor) do
      Investor.create!(email: 'today.op@test.com', name: 'Today Op', status: 'ACTIVE')
    end

    let!(:portfolio) do
      Portfolio.create!(investor: investor, current_balance: 1010)
    end

    before do
      InvestorMonthlyAnnexRow.create!(
        investor: investor,
        month: Date.new(2026, 4, 1),
        return_percent: 0,
        return_usd: 0,
        portfolio_value: 1000,
        opening_snapshot: false,
        source: 'spreadsheet',
      )
    end

    it 'includes today OPERATING_RESULT in RDO M % even when generated before 17:00' do
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: 10,
        previous_balance: 1000,
        new_balance: 1010,
        date: Time.zone.local(2026, 7, 31, 17, 0, 0),
        status: 'COMPLETED',
      )
      DailyOperatingResult.create!(
        date: Date.new(2026, 7, 31),
        percent: 1.0,
        applied_at: Time.zone.local(2026, 7, 31, 14, 0, 0),
        applied_by: User.create!(
          email: 'admin-today@test.com',
          name: 'Admin',
          role: 'SUPERADMIN',
          provider: 'google_oauth2',
          uid: 'today-op-admin',
        ),
      )

      # Wall clock before the canonical 17:00 movement_time — previously excluded today.
      travel_to Time.zone.local(2026, 7, 31, 15, 0, 0) do
        report = described_class.new(investor: investor, report_month: Date.new(2026, 7, 1)).build
        jul = report[:annex_rows].find { |r| r[:month] == '2026-07' }

        expect(jul[:portfolio_value]).to eq(1010.0)
        expect(jul[:return_usd]).to be_within(0.01).of(10.0)
        expect(jul[:return_percent]).to be_within(0.01).of(1.0)
        expect(report[:summary][:winbit_monthly_return_percent]).to eq(1.0)
      end
    end
  end

  describe 'investor with no spreadsheet history (joined natively on the platform)' do
    let(:native_investor) do
      Investor.create!(email: 'native@example.com', name: 'Native Investor', status: 'ACTIVE')
    end

    let!(:native_portfolio) do
      Portfolio.create!(
        investor: native_investor,
        current_balance: 567.63,
        total_invested: 553,
        strategy_return_all_usd: 14.63,
        strategy_return_all_percent: 2.65,
        strategy_return_ytd_usd: 14.63,
        strategy_return_ytd_percent: 2.65,
      )
    end

    before do
      PortfolioHistory.create!(
        investor: native_investor,
        event: 'DEPOSIT',
        amount: 553,
        previous_balance: 0,
        new_balance: 553,
        date: Time.zone.local(2026, 5, 10, 19, 0, 0),
        status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: native_investor,
        event: 'OPERATING_RESULT',
        amount: 14.63,
        previous_balance: 553,
        new_balance: 567.63,
        date: Time.zone.local(2026, 8, 15, 19, 0, 0),
        status: 'COMPLETED',
      )
    end

    it 'does not blank out Acumulado 2026 just because there is no genesis/spreadsheet opening row' do
      travel_to Time.zone.local(2026, 8, 29, 12, 0, 0) do
        report = described_class.new(investor: native_investor, report_month: Date.new(2026, 8, 1)).build

        expect(report[:summary][:accumulated_2026_usd]).to be_within(0.01).of(14.63)
        expect(report[:summary][:accumulated_2026_percent]).to eq(2.65)
      end
    end

    it 'uses the date/balance of the real first deposit as saldo inicial 2026, not Jan 1st at $0' do
      travel_to Time.zone.local(2026, 8, 29, 12, 0, 0) do
        report = described_class.new(investor: native_investor, report_month: Date.new(2026, 8, 1)).build

        expect(report[:summary][:year_opening_date]).to eq('2026-05-10')
        expect(report[:summary][:year_opening_balance_usd]).to eq(553.0)
      end
    end
  end

  describe 'net_contributed_after_withdrawals_usd (Camilo Giordano case)' do
    let(:investor) do
      Investor.create!(email: 'camilo-recon@example.com', name: 'Camilo Recon', status: 'ACTIVE')
    end

    let!(:admin) { User.create!(email: 'admin-recon@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'recon-1') }

    let!(:portfolio) do
      Portfolio.create!(
        investor: investor,
        current_balance: 8238.41,
        strategy_return_all_usd: 3243.35,
        strategy_return_all_percent: 64.2405,
      )
    end

    before do
      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 5050,
        previous_balance: 0, new_balance: 5050,
        date: Time.zone.local(2026, 5, 1, 19, 0, 0), status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor, event: 'TRADING_FEE', amount: -54.94,
        previous_balance: 8293.35, new_balance: 8238.41,
        date: Time.zone.local(2026, 8, 15, 19, 0, 0), status: 'COMPLETED',
      )
    end

    it 'is deposits minus withdrawals only - trading fees are a cost, not a capital reduction' do
      report = described_class.new(investor: investor, report_month: Date.new(2026, 8, 1)).build
      summary = report[:summary]

      # 5050 deposited, 0 withdrawn - the $54.94 in fees does NOT reduce this.
      expect(summary[:net_contributed_after_withdrawals_usd]).to eq(5050.0)
      # So it does NOT need to reconcile exactly against the TWR return once
      # fees are involved - that's expected, not a bug.
      expect(
        (summary[:portfolio_value_usd] - summary[:net_contributed_after_withdrawals_usd]).round(2)
      ).not_to eq(summary[:accumulated_since_entry_usd])
    end
  end
end
