require 'rails_helper'

RSpec.describe Requests::ReverseApprovedWithdrawal, type: :service do
  let!(:admin) { User.create!(email: 'admin-reverse@test.com', name: 'Admin', role: 'ADMIN') }
  let!(:investor) { Investor.create!(email: 'reverse-investor@test.com', name: 'Investor', status: 'ACTIVE') }
  # New model: investor receives full 1000, fee (27.27) is charged additionally.
  # Balance after approval: 5500 - 1000 (withdrawal) - 27.27 (fee) = 4472.73
  # total_invested after approval: 5000 - 1000 = 4000 (fee does not reduce total_invested)
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 4472.73, total_invested: 4000) }
  # Simulate history: DEPOSIT 5000, OPERATING_RESULT 500 -> balance 5500, total_invested 5000;
  # then WITHDRAWAL 1000, TRADING_FEE 27.27 -> balance 4472.73, total_invested 4000
  let!(:prior_deposit) do
    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 5000,
      previous_balance: 0,
      new_balance: 5000,
      status: 'COMPLETED',
      date: 3.days.ago
    )
  end
  let!(:operating) do
    PortfolioHistory.create!(
      investor: investor,
      event: 'OPERATING_RESULT',
      amount: 500,
      previous_balance: 5000,
      new_balance: 5500,
      status: 'COMPLETED',
      date: 2.days.ago
    )
  end
  let!(:withdrawal_history) do
    PortfolioHistory.create!(
      investor: investor,
      event: 'WITHDRAWAL',
      amount: 1000,
      previous_balance: 5500,
      new_balance: 4500,
      status: 'COMPLETED',
      date: 1.day.ago
    )
  end
  let!(:fee_history) do
    PortfolioHistory.create!(
      investor: investor,
      event: 'TRADING_FEE',
      amount: -27.27,
      previous_balance: 4500,
      new_balance: 4472.73,
      status: 'COMPLETED',
      date: 1.day.ago
    )
  end
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

  it 'reverts portfolio impact, voids linked fee, and marks request REVERSED' do
    service = described_class.new(request_id: request.id, reversed_by: admin)

    expect { service.call }.to change { PortfolioHistory.count }.by(2)

    portfolio.reload
    fee.reload
    request.reload

    # current_balance restored: 4472.73 + 27.27 (fee refund) + 1000 (withdrawal reversal) = 5500
    expect(portfolio.current_balance.to_f.round(2)).to eq(5500.0)
    # total_invested restored: 4000 + 1000 = 5000
    expect(portfolio.total_invested.to_f.round(2)).to eq(5000.0)
    expect(fee.voided_at).to be_present
    expect(fee.voided_by_id).to eq(admin.id)

    expect(request.status).to eq('REVERSED')
    expect(request.reversed_at).to be_present
    expect(request.reversed_by_id).to eq(admin.id)
  end
end
