# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MonthlyReportBuilder do
  describe 'Fabrizio Bruno — annex totals through June 2026' do
    let(:investor) do
      Investor.create!(email: 'fabrabr190987@gmail.com', name: 'Fabrizio Bruno', status: 'ACTIVE')
    end

    let!(:portfolio) do
      Portfolio.create!(
        investor: investor,
        current_balance: 7293,
        strategy_return_ytd_usd: 392,
        strategy_return_ytd_percent: 5.64,
        strategy_return_all_usd: 5430,
        strategy_return_all_percent: 73.8,
      )
    end

    before do
      [
        [Date.new(2025, 12, 1), nil, nil, 0, 0, 0, 6951, true],
        [Date.new(2026, 1, 1), 0, -1, 0, 0, 0, 6950, false],
        [Date.new(2026, 2, 1), 2, 161, 0, 0, 0, 7111, false],
        [Date.new(2026, 3, 1), 2.3, 164, 0, 0, 97, 7178, false],
        [Date.new(2026, 4, 1), 2.5, 179, 0, 0, 0, 7357, false],
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

      PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 7357,
        previous_balance: 0,
        new_balance: 7357,
        date: Time.zone.local(2026, 5, 1, 19, 0, 0),
        status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: -131,
        previous_balance: 7357,
        new_balance: 7226,
        date: Time.zone.local(2026, 5, 20, 19, 0, 0),
        status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'TRADING_FEE',
        amount: -49,
        previous_balance: 7226,
        new_balance: 7177,
        date: Time.zone.local(2026, 6, 15, 19, 0, 0),
        status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: 117,
        previous_balance: 7177,
        new_balance: 7294,
        date: Time.zone.local(2026, 6, 20, 19, 0, 0),
        status: 'COMPLETED',
      )
    end

    it 'keeps monthly RDO gross, but summary YTD equals net (gross − CST)' do
      travel_to Time.zone.local(2026, 6, 25, 12, 0, 0) do
        report = described_class.new(investor: investor, report_month: Date.new(2026, 6, 1)).build
        data_rows = report[:annex_rows].reject { |r| r[:opening_snapshot] || r[:entry_row] }

        expect(data_rows.map { |r| r[:return_usd] }).to eq([-1, 161, 164, 179, -131, 117])
        expect(data_rows.map { |r| r[:service_cost] }).to eq([0, 0, 97, 0, 0, 49])

        total_rdo_gross = data_rows.sum { |r| r[:return_usd].to_f }
        total_cst = data_rows.sum { |r| r[:service_cost].to_f }
        total_rdo_net = total_rdo_gross - total_cst

        expect(total_rdo_gross).to eq(489.0)
        expect(total_cst).to eq(146.0)
        expect(total_rdo_net).to eq(343.0)
        # Must NOT use live panel YTD (392) which ignores platform CST and mismatches annex.
        expect(report[:summary][:accumulated_2026_usd]).to eq(343.0)
        expect(report[:summary][:accumulated_2026_usd]).not_to eq(392.0)
      end
    end
  end
end
