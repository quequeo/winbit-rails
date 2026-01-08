require 'test_helper'

class ApiPublicRequestsTest < ActionDispatch::IntegrationTest
  test 'POST /api/public/requests creates deposit request' do
    investor = Investor.create!(email: 'r@example.com', name: 'r', code: 'R-1', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
      params: {
        email: investor.email,
        type: 'DEPOSIT',
        amount: 50,
        method: 'USDT',
        network: 'TRC20',
        transactionHash: '0xabc',
      },
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 'PENDING', json.dig('data', 'status')
    assert_equal 50.0, json.dig('data', 'amount')
    assert_equal 'USDT', json.dig('data', 'method')
  end

  test 'POST /api/public/requests validates withdrawal balance' do
    investor = Investor.create!(email: 'w@example.com', name: 'w', code: 'W-1', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 10, total_invested: 10)

    post '/api/public/requests',
      params: {
        email: investor.email,
        type: 'WITHDRAWAL',
        amount: 50,
        method: 'USDT',
        network: 'TRC20',
      },
      as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal 'Insufficient balance', json['error']
  end
end
