# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::DataSignature do
  let(:investor) { Investor.create!(email: 'firma@test.com', name: 'Firma Prueba', status: 'ACTIVE') }
  let(:other) { Investor.create!(email: 'otro@test.com', name: 'Otro', status: 'ACTIVE') }
  let(:admin) { User.create!(email: 'firma-admin@test.com', name: 'A', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'firma-1') }

  let!(:deposit) do
    PortfolioHistory.create!(
      investor: investor, event: 'DEPOSIT', amount: 1000, previous_balance: 0, new_balance: 1000,
      date: Time.zone.local(2026, 9, 5, 12), status: 'COMPLETED',
    )
  end

  def signature(for_investor = investor)
    described_class.for_investors(month: '2026-09', investor_ids: [ for_investor.id ])[for_investor.id]
  end

  it 'is stable while nothing changes' do
    expect(signature).to eq(signature)
  end

  it 'changes when a movement dated in the month is added (e.g. the quarterly fee loaded afterwards)' do
    before = signature
    PortfolioHistory.create!(
      investor: investor, event: 'TRADING_FEE', amount: -50, previous_balance: 1000, new_balance: 950,
      date: Time.zone.local(2026, 9, 30, 17), status: 'COMPLETED',
    )
    expect(signature).not_to eq(before)
  end

  it 'changes when a movement of the month is deleted or edited' do
    before = signature
    deposit.update!(amount: 1200, new_balance: 1200)
    edited = signature
    expect(edited).not_to eq(before)

    deposit.destroy!
    expect(signature).not_to eq(edited)
  end

  it "ignores movements after the month and other investors' movements" do
    before = signature
    PortfolioHistory.create!(
      investor: investor, event: 'OPERATING_RESULT', amount: 10, previous_balance: 1000, new_balance: 1010,
      date: Time.zone.local(2026, 10, 1, 19), status: 'COMPLETED',
    )
    PortfolioHistory.create!(
      investor: other, event: 'DEPOSIT', amount: 500, previous_balance: 0, new_balance: 500,
      date: Time.zone.local(2026, 9, 10, 12), status: 'COMPLETED',
    )
    expect(signature).to eq(before)
  end

  it "changes for everyone when the month's trades change" do
    before = signature
    StrategyOperation.create!(
      operation_date: Date.new(2026, 9, 10), asset: 'MNQ', direction: 'LONG', opened_at: '10:00', closed_at: '10:30',
      result_usd: 100, ratio: 1.0, source: 'manual', result_label: 'POSITIVO', created_by: admin,
    )
    expect(signature).not_to eq(before)
  end

  it 'changes when the way the report is calculated changes, even with the same data' do
    before = signature
    stub_const("#{described_class}::CALCULATION_VERSION", described_class::CALCULATION_VERSION + 1)
    expect(signature).not_to eq(before)
  end
end
