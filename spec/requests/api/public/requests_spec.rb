require 'rails_helper'

RSpec.describe 'Public requests', type: :request do
  it 'POST /api/public/requests creates deposit request' do
    investor = Investor.create!(email: 'r@example.com', name: 'r', code: 'R-1', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'USDT',
           network: 'TRC20',
           transactionHash: '0xabc'
         },
         as: :json

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'status')).to eq('PENDING')
    expect(json.dig('data', 'amount')).to eq(50.0)
    expect(json.dig('data', 'method')).to eq('USDT')
  end

  it 'POST /api/public/requests validates withdrawal balance' do
    investor = Investor.create!(email: 'w@example.com', name: 'w', code: 'W-1', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 10, total_invested: 10)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 50,
           method: 'USDT',
           network: 'TRC20'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Insufficient balance')
  end
end
