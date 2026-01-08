require 'test_helper'

class ApiPublicInvestorsTest < ActionDispatch::IntegrationTest
  test 'GET /api/public/investor/:email returns investor + portfolio' do
    investor = Investor.create!(email: 'test@example.com', name: 'juan perez', code: 'JP-1', status: 'ACTIVE')
    Portfolio.create!(
      investor_id: investor.id,
      current_balance: 100,
      total_invested: 80,
      accumulated_return_usd: 20,
      accumulated_return_percent: 25,
      annual_return_usd: 10,
      annual_return_percent: 12.5,
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 'test@example.com', json.dig('data', 'investor', 'email')
    assert_equal 'Juan Perez', json.dig('data', 'investor', 'name')
    assert_equal 'JP-1', json.dig('data', 'investor', 'code')
    assert_equal 100.0, json.dig('data', 'portfolio', 'currentBalance')
  end

  test 'GET /api/public/investor/:email returns 404 when missing' do
    get "/api/public/investor/#{CGI.escape('missing@example.com')}"
    assert_response :not_found
  end

  test 'GET /api/public/investor/:email returns 403 when inactive' do
    Investor.create!(email: 'inactive@example.com', name: 'x', code: 'X-1', status: 'INACTIVE')

    get "/api/public/investor/#{CGI.escape('inactive@example.com')}"
    assert_response :forbidden
  end

  test 'GET /api/public/investor/:email/history returns history desc' do
    investor = Investor.create!(email: 'h@example.com', name: 'h', code: 'H-1', status: 'ACTIVE')

    PortfolioHistory.create!(
      investor_id: investor.id,
      date: Time.utc(2024, 2, 1),
      event: 'Depósito',
      amount: 100,
      previous_balance: 0,
      new_balance: 100,
      status: 'COMPLETED',
    )
    PortfolioHistory.create!(
      investor_id: investor.id,
      date: Time.utc(2024, 3, 1),
      event: 'Retiro',
      amount: 10,
      previous_balance: 100,
      new_balance: 90,
      status: 'COMPLETED',
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 2, json['data'].length
    assert_equal 'Retiro', json['data'][0]['event']
    assert_equal 'Depósito', json['data'][1]['event']
  end
end
