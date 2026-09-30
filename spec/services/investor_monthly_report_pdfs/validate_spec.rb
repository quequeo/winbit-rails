# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::Validate do
  let(:admin) do
    User.create!(email: 'admin-validate@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'validate-1')
  end

  # Report month is May 2026 (right after MonthlyReportBuilder's spreadsheet
  # cutoff), so the annex row's "previous row" is the synthetic $0 entry row
  # instead of a real prior month - keeps portfolio_value_at from falling
  # back to Portfolio#current_balance for a month with no history yet, which
  # would corrupt the May row's own math (see May 2026 deposit below).
  # strategy_return_ytd_usd is seeded to match the real May gain so the
  # accumulated-year check ties out without a fee in the picture.
  def build_investor(name:, email:, current_balance:, ytd_usd: 0)
    investor = Investor.create!(email: email, name: name, status: 'ACTIVE')
    Portfolio.create!(
      investor: investor,
      current_balance: current_balance,
      total_invested: current_balance,
      strategy_return_all_usd: ytd_usd,
      strategy_return_all_percent: 0,
      strategy_return_ytd_usd: ytd_usd,
      strategy_return_ytd_percent: 0,
    )
    investor
  end

  describe 'a clean month' do
    it 'has no warnings when everything ties out' do
      investor = build_investor(name: 'Ana Warnings', email: 'ana.warnings@example.com', current_balance: 6162, ytd_usd: 162)

      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 6000,
        previous_balance: 0, new_balance: 6000,
        date: Time.zone.local(2026, 5, 1, 19, 0, 0), status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor, event: 'OPERATING_RESULT', amount: 162,
        previous_balance: 6000, new_balance: 6162,
        date: Time.zone.local(2026, 5, 10, 19, 0, 0), status: 'COMPLETED',
      )
      StrategyOperation.create!(
        operation_date: Date.new(2026, 5, 10), asset: 'MNQ', direction: 'LONG',
        opened_at: '10:00', closed_at: '11:00', result_usd: 162, ratio: 1.5,
        source: 'manual', result_label: 'POSITIVO', created_by: admin,
      )

      travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) do
        warnings = described_class.call(investor: investor, report_month: '2026-05')
        expect(warnings).to eq([])
      end
    end
  end

  describe 'a trade missing its direction' do
    it 'warns about the specific date and asset' do
      investor = build_investor(name: 'Bruno Warnings', email: 'bruno.warnings@example.com', current_balance: 6100, ytd_usd: 100)

      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 6000,
        previous_balance: 0, new_balance: 6000,
        date: Time.zone.local(2026, 5, 1, 19, 0, 0), status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor, event: 'OPERATING_RESULT', amount: 100,
        previous_balance: 6000, new_balance: 6100,
        date: Time.zone.local(2026, 5, 10, 19, 0, 0), status: 'COMPLETED',
      )
      StrategyOperation.create!(
        operation_date: Date.new(2026, 5, 10), asset: 'MES', direction: nil,
        opened_at: '10:00', closed_at: '11:00', result_usd: 100, ratio: 1.2,
        source: 'manual', result_label: 'POSITIVO', created_by: admin,
      )

      travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) do
        warnings = described_class.call(investor: investor, report_month: '2026-05')
        expect(warnings).to include(match(/10\/05.*MES.*dirección/))
      end
    end
  end

  describe 'a trade with no matching OPERATING_RESULT' do
    it 'warns that the operations sum does not match the monthly return' do
      investor = build_investor(name: 'Carla Warnings', email: 'carla.warnings@example.com', current_balance: 6100, ytd_usd: 100)

      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 6000,
        previous_balance: 0, new_balance: 6000,
        date: Time.zone.local(2026, 5, 1, 19, 0, 0), status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor, event: 'OPERATING_RESULT', amount: 100,
        previous_balance: 6000, new_balance: 6100,
        date: Time.zone.local(2026, 5, 10, 19, 0, 0), status: 'COMPLETED',
      )
      # No StrategyOperation for 2026-05-10: MonthlyOperationsReport silently
      # drops this OPERATING_RESULT from the trades list (build_trade returns
      # nil without a matching op), so the operations sum understates the
      # annex row's return_usd - exactly the data gap this check exists for.

      travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) do
        warnings = described_class.call(investor: investor, report_month: '2026-05')
        expect(warnings).to include(match(/suma de las operaciones/))
      end
    end
  end

  describe 'a portfolio balance that drifted from the last history entry' do
    it 'warns that the last annex value does not match the current portfolio value' do
      investor = build_investor(name: 'Diego Warnings', email: 'diego.warnings@example.com', current_balance: 9999, ytd_usd: 100)

      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 6000,
        previous_balance: 0, new_balance: 6000,
        date: Time.zone.local(2026, 6, 1, 19, 0, 0), status: 'COMPLETED',
      )
      PortfolioHistory.create!(
        investor: investor, event: 'OPERATING_RESULT', amount: 100,
        previous_balance: 6000, new_balance: 6100,
        date: Time.zone.local(2026, 6, 10, 19, 0, 0), status: 'COMPLETED',
      )
      StrategyOperation.create!(
        operation_date: Date.new(2026, 6, 10), asset: 'MNQ', direction: 'LONG',
        opened_at: '10:00', closed_at: '11:00', result_usd: 100, ratio: 1.2,
        source: 'manual', result_label: 'POSITIVO', created_by: admin,
      )

      # report_month == the travel_to month here (June, "now") is required
      # to trigger this specific check: only for the current month does
      # MonthlyReportBuilder#portfolio_value_for_summary read
      # Portfolio#current_balance directly (elsewhere it derives the value
      # from PortfolioHistory) - so it's the one figure that can genuinely
      # drift from what PortfolioHistory says happened.
      travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) do
        warnings = described_class.call(investor: investor, report_month: '2026-06')
        expect(warnings).to include(match(/último valor del historial/))
      end
    end
  end
end
