require 'rails_helper'

RSpec.describe Requests::ReverseApprovedDeposit, type: :service do
  let!(:admin) { User.create!(email: 'admin-reverse-dep@test.com', name: 'Admin', role: 'ADMIN') }
  let!(:investor) { Investor.create!(email: 'reverse-dep-investor@test.com', name: 'Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 6000, total_invested: 6000) }
  let!(:request) do
    InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 1000,
      status: 'APPROVED',
      requested_at: 2.days.ago,
      processed_at: 1.day.ago
    )
  end

  before do
    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 5000,
      previous_balance: 0,
      new_balance: 5000,
      status: 'COMPLETED',
      date: 3.days.ago
    )
    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 1000,
      previous_balance: 5000,
      new_balance: 6000,
      status: 'COMPLETED',
      date: 1.day.ago
    )
  end

  it 'reverts portfolio impact and marks request REVERSED' do
    service = described_class.new(request_id: request.id, reversed_by: admin)

    expect { service.call }.to change { PortfolioHistory.count }.by(1)

    portfolio.reload
    request.reload

    expect(portfolio.current_balance.to_f.round(2)).to eq(5000.0)
    expect(portfolio.total_invested.to_f.round(2)).to eq(5000.0)
    expect(request.status).to eq('REVERSED')
    expect(request.reversed_at).to be_present
    expect(request.reversed_by_id).to eq(admin.id)

    ph = PortfolioHistory.find_by(investor: investor, event: 'DEPOSIT_REVERSAL')
    expect(ph).to be_present
    expect(ph.amount.to_f).to eq(1000.0)
  end
end
