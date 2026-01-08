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
    expect(history.event).to eq('Depósito')
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
end
