require 'rails_helper'

RSpec.describe Requests::ReverseApprovedWithdrawal, type: :service do
  let!(:admin) { User.create!(email: 'admin-reverse@test.com', name: 'Admin', role: 'ADMIN') }
  let!(:investor) { Investor.create!(email: 'reverse-investor@test.com', name: 'Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 4500, total_invested: 4027.27) }
  let!(:request) do
    InvestorRequest.create!(
      investor: investor,
      request_type: 'WITHDRAWAL',
      method: 'USDT',
      amount: 1000,
      status: 'APPROVED',
      requested_at: 2.days.ago,
      processed_at: 1.day.ago
    )
  end
  let!(:fee) do
    TradingFee.create!(
      investor: investor,
      applied_by: admin,
      period_start: Date.current,
      period_end: Date.current + 1.day,
      profit_amount: 90.91,
      fee_percentage: 30,
      fee_amount: 27.27,
      source: 'WITHDRAWAL',
      withdrawal_amount: 1000,
      withdrawal_request_id: request.id,
      applied_at: request.processed_at
    )
  end

  it 'reverts portfolio impact and voids linked withdrawal trading fee' do
    service = described_class.new(request_id: request.id, reversed_by: admin)

    expect { service.call }.to change { PortfolioHistory.count }.by(2)

    portfolio.reload
    fee.reload

    expect(portfolio.current_balance.to_f.round(2)).to eq(5500.0)
    expect(portfolio.total_invested.to_f.round(2)).to eq(5000.0)
    expect(fee.voided_at).to be_present
    expect(fee.voided_by_id).to eq(admin.id)
  end
end
