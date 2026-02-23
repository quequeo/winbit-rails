require 'rails_helper'

RSpec.describe 'Admin requests', type: :request do
  before do
    user = User.create!(email: 'admin@example.com', role: 'ADMIN')
    sign_in user, scope: :user
  end

  it 'POST /api/admin/requests/:id/approve approves deposit and creates history' do
    investor = Investor.create!(email: 'a@example.com', name: 'a', status: 'ACTIVE')
    portfolio = Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'DEPOSIT',
      amount: 50,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current
    )

    post "/api/admin/requests/#{req.id}/approve"

    expect(response).to have_http_status(:no_content)

    portfolio.reload
    req.reload
    expect(req.status).to eq('APPROVED')
    expect(portfolio.current_balance.to_f).to be > 100.0

    history = PortfolioHistory.where(investor_id: investor.id).order(date: :desc).first
    expect(history.event).to eq('DEPOSIT')
  end

  it 'POST /api/admin/requests/:id/reject rejects pending request' do
    investor = Investor.create!(email: 'b@example.com', name: 'b', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 10,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current
    )

    post "/api/admin/requests/#{req.id}/reject"

    expect(response).to have_http_status(:no_content)
    req.reload
    expect(req.status).to eq('REJECTED')
  end

  it 'POST /api/admin/requests/:id/approve applies trading fee por retiro when there are pending profits' do
    investor = Investor.create!(email: 'fee-withdraw@test.com', name: 'wf', status: 'ACTIVE', trading_fee_percentage: 30)
    portfolio = Portfolio.create!(investor_id: investor.id, current_balance: 5500, total_invested: 5000)
    PortfolioHistory.create!(
      investor_id: investor.id,
      event: 'OPERATING_RESULT',
      amount: 500,
      previous_balance: 5000,
      new_balance: 5500,
      status: 'COMPLETED',
      date: 1.day.ago
    )

    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 1000,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current
    )

    post "/api/admin/requests/#{req.id}/approve"

    expect(response).to have_http_status(:no_content)
    req.reload
    portfolio.reload

    expect(req.status).to eq('APPROVED')
    expect(portfolio.current_balance.to_f.round(2)).to eq(4500.0)

    fee = TradingFee.find_by(withdrawal_request_id: req.id)
    expect(fee).to be_present
    expect(fee.source).to eq('WITHDRAWAL')

    withdrawal_history = PortfolioHistory.where(investor_id: investor.id, event: 'WITHDRAWAL').order(date: :desc).first
    fee_history = PortfolioHistory.where(investor_id: investor.id, event: 'TRADING_FEE').order(date: :desc).first
    expect(withdrawal_history).to be_present
    expect(fee_history).to be_present
    expect((withdrawal_history.amount.to_f + fee_history.amount.to_f.abs).round(2)).to eq(1000.0)
  end

  it 'POST /api/admin/requests uses provided past date for request and processing' do
    investor = Investor.create!(email: 'c@example.com', name: 'c', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/admin/requests', params: {
      investor_id: investor.id,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 50,
      status: 'APPROVED',
      processed_at: '2025-01-10',
    }

    expect(response).to have_http_status(:created)
    req_id = JSON.parse(response.body).dig('data', 'id')
    req = InvestorRequest.find(req_id)

    expect(req.status).to eq('APPROVED')
    expect(req.requested_at.to_date).to eq(Date.new(2025, 1, 10))
    expect(req.processed_at.to_date).to eq(Date.new(2025, 1, 10))
  end

  it 'DELETE /api/admin/requests/:id reverses approved withdrawal and linked fee before deleting' do
    investor = Investor.create!(email: 'reverse-delete@example.com', name: 'rd', status: 'ACTIVE')
    portfolio = Portfolio.create!(investor_id: investor.id, current_balance: 4500, total_invested: 4027.27)

    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 1000,
      method: 'USDT',
      status: 'APPROVED',
      requested_at: 2.days.ago,
      processed_at: 1.day.ago
    )

    admin = User.find_by(email: 'admin@example.com')
    fee = TradingFee.create!(
      investor: investor,
      applied_by: admin,
      period_start: Date.current,
      period_end: Date.current + 1.day,
      profit_amount: 90.91,
      fee_percentage: 30,
      fee_amount: 27.27,
      source: 'WITHDRAWAL',
      withdrawal_amount: 1000,
      withdrawal_request_id: req.id,
      applied_at: req.processed_at
    )

    delete "/api/admin/requests/#{req.id}"

    expect(response).to have_http_status(:no_content)
    expect(InvestorRequest.find_by(id: req.id)).to be_nil

    portfolio.reload
    fee.reload
    expect(portfolio.current_balance.to_f.round(2)).to eq(5500.0)
    expect(fee.voided_at).to be_present
  end
end
