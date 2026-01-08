require 'test_helper'

class ApiAdminRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: 'admin@example.com', role: 'ADMIN')
    sign_in @user
  end

  test 'POST /api/admin/requests/:id/approve approves deposit and creates history' do
    investor = Investor.create!(email: 'a@example.com', name: 'a', code: 'A-1', status: 'ACTIVE')
    portfolio = Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'DEPOSIT',
      amount: 50,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current,
    )

    post "/api/admin/requests/#{req.id}/approve"
    assert_response :no_content

    portfolio.reload
    req.reload

    assert_equal 'APPROVED', req.status
    assert portfolio.current_balance.to_f > 100.0

    history = PortfolioHistory.where(investor_id: investor.id).order(date: :desc).first
    assert_equal 'Depósito', history.event
  end

  test 'POST /api/admin/requests/:id/reject rejects pending request' do
    investor = Investor.create!(email: 'b@example.com', name: 'b', code: 'B-1', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    req = InvestorRequest.create!(
      investor_id: investor.id,
      request_type: 'WITHDRAWAL',
      amount: 10,
      method: 'USDT',
      status: 'PENDING',
      requested_at: Time.current,
    )

    post "/api/admin/requests/#{req.id}/reject"
    assert_response :no_content

    req.reload
    assert_equal 'REJECTED', req.status
  end
end
