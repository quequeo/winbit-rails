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
    # New model: investor receives full 1000; fee 27.27 is charged additionally.
    # new_balance = 5500 - 1000 - 27.27 = 4472.73
    expect(portfolio.current_balance.to_f.round(2)).to eq(4472.73)

    fee = TradingFee.find_by(withdrawal_request_id: req.id)
    expect(fee).to be_present
    expect(fee.source).to eq('WITHDRAWAL')

    withdrawal_history = PortfolioHistory.where(investor_id: investor.id, event: 'WITHDRAWAL').order(date: :desc).first
    fee_history = PortfolioHistory.where(investor_id: investor.id, event: 'TRADING_FEE').order(date: :desc).first
    expect(withdrawal_history).to be_present
    expect(fee_history).to be_present
    # Investor receives full requested amount; fee is charged on top
    expect(withdrawal_history.amount.to_f).to eq(1000.0)
    expect(fee_history.amount.to_f).to be < 0
    expect(withdrawal_history.amount.to_f + fee_history.amount.to_f.abs).to be > 1000.0
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

  it 'POST /api/admin/requests supports status REJECTED on create' do
    investor = Investor.create!(email: 'rej-create@example.com', name: 'rc', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/admin/requests', params: {
      investor_id: investor.id,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 50,
      status: 'REJECTED'
    }

    expect(response).to have_http_status(:created)
    req_id = JSON.parse(response.body).dig('data', 'id')
    req = InvestorRequest.find(req_id)
    expect(req.status).to eq('REJECTED')
    expect(req.processed_at).to be_present
  end

  it 'PATCH /api/admin/requests/:id does not allow changing status directly' do
    investor = Investor.create!(email: 'upd@example.com', name: 'upd', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)
    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 10,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current
    )

    patch "/api/admin/requests/#{req.id}", params: {
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      method: 'USDT',
      amount: 10,
      status: 'APPROVED'
    }

    expect(response).to have_http_status(:unprocessable_entity)
    req.reload
    expect(req.status).to eq('PENDING')
  end

  it 'PATCH /api/admin/requests/:id returns bad_request when required params are missing' do
    investor = Investor.create!(email: 'missing-update@example.com', name: 'mu', status: 'ACTIVE')
    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 10,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current
    )

    patch "/api/admin/requests/#{req.id}", params: {
      request_type: 'WITHDRAWAL',
      method: 'USDT',
      amount: 10
    }

    expect(response).to have_http_status(:bad_request)
  end

  it 'POST /api/admin/requests/:id/approve returns bad_request when service fails' do
    investor = Investor.create!(email: 'approve-fail@example.com', name: 'af', status: 'ACTIVE')
    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'DEPOSIT',
      amount: 10,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current
    )

    service = instance_double(Requests::Approve)
    allow(Requests::Approve).to receive(:new).and_return(service)
    allow(service).to receive(:call).and_raise(StandardError, 'approve error')

    post "/api/admin/requests/#{req.id}/approve"

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)['error']).to include('approve error')
  end

  it 'POST /api/admin/requests/:id/reject returns bad_request when service fails' do
    investor = Investor.create!(email: 'reject-fail@example.com', name: 'rf', status: 'ACTIVE')
    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 10,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current
    )

    service = instance_double(Requests::Reject)
    allow(Requests::Reject).to receive(:new).and_return(service)
    allow(service).to receive(:call).and_raise(StandardError, 'reject error')

    post "/api/admin/requests/#{req.id}/reject"

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)['error']).to include('reject error')
  end

  it 'DELETE /api/admin/requests/:id returns 422 for approved withdrawal (use reverse)' do
    investor = Investor.create!(email: 'reverse-delete@example.com', name: 'rd', status: 'ACTIVE')
    portfolio = Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)
    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 10,
      method: 'USDT',
      status: 'APPROVED',
      requested_at: 2.days.ago,
      processed_at: 1.day.ago
    )

    delete "/api/admin/requests/#{req.id}"

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('Revertir')
    expect(InvestorRequest.find_by(id: req.id)).to be_present
  end

  it 'POST /api/admin/requests/:id/reverse reverts approved withdrawal and sets REVERSED' do
    investor = Investor.create!(email: 'reverse-post@example.com', name: 'rp', status: 'ACTIVE')
    portfolio = Portfolio.create!(investor_id: investor.id, current_balance: 4472.73, total_invested: 4000)
    # Simulate history: DEPOSIT 5000, OPERATING_RESULT 500 -> 5500; WITHDRAWAL 1000, TRADING_FEE 27.27 -> 4472.73
    PortfolioHistory.create!(investor: investor, event: 'DEPOSIT', amount: 5000, previous_balance: 0, new_balance: 5000, status: 'COMPLETED', date: 3.days.ago)
    PortfolioHistory.create!(investor: investor, event: 'OPERATING_RESULT', amount: 500, previous_balance: 5000, new_balance: 5500, status: 'COMPLETED', date: 2.days.ago)
    PortfolioHistory.create!(investor: investor, event: 'WITHDRAWAL', amount: 1000, previous_balance: 5500, new_balance: 4500, status: 'COMPLETED', date: 1.day.ago)
    PortfolioHistory.create!(investor: investor, event: 'TRADING_FEE', amount: -27.27, previous_balance: 4500, new_balance: 4472.73, status: 'COMPLETED', date: 1.day.ago)
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
      withdrawal_request_id: req.id,
      applied_at: req.processed_at
    )

    post "/api/admin/requests/#{req.id}/reverse"

    expect(response).to have_http_status(:no_content)
    req.reload
    expect(req.status).to eq('REVERSED')
    expect(req.reversed_at).to be_present
    expect(req.reversed_by_id).to eq(admin.id)

    portfolio.reload
    expect(portfolio.current_balance.to_f.round(2)).to eq(5500.0)
    expect(portfolio.total_invested.to_f.round(2)).to eq(5000.0)
  end

  it 'POST /api/admin/requests/:id/reverse returns bad_request when service fails' do
    investor = Investor.create!(email: 'reverse-fail@example.com', name: 'rf', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)
    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 10,
      method: 'USDT',
      status: 'APPROVED',
      requested_at: Time.current,
      processed_at: Time.current
    )

    service = instance_double(Requests::ReverseApprovedWithdrawal)
    allow(Requests::ReverseApprovedWithdrawal).to receive(:new).and_return(service)
    allow(service).to receive(:call).and_raise(StandardError, 'reverse error')

    post "/api/admin/requests/#{req.id}/reverse"

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)['error']).to include('reverse error')
  end
end
