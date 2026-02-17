require 'rails_helper'

RSpec.describe 'Public requests', type: :request do
  it 'POST /api/public/requests creates deposit request with attachment' do
    investor = Investor.create!(email: 'r@example.com', name: 'r', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'USDT',
           network: 'TRC20',
           transactionHash: '0xabc',
           attachmentUrl: 'data:image/png;base64,abc123'
         },
         as: :json

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'status')).to eq('PENDING')
    expect(json.dig('data', 'amount')).to eq(50.0)
    expect(json.dig('data', 'method')).to eq('USDT')
  end

  it 'POST /api/public/requests rejects non-cash deposit without attachment' do
    investor = Investor.create!(email: 'na@example.com', name: 'na', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'CRYPTO'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to include('Attachment is required')
  end

  it 'POST /api/public/requests allows cash deposit without attachment' do
    investor = Investor.create!(email: 'cash@example.com', name: 'cash', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_ARS'
         },
         as: :json

    expect(response).to have_http_status(:created)
  end

  it 'POST /api/public/requests validates withdrawal balance' do
    investor = Investor.create!(email: 'w@example.com', name: 'w', status: 'ACTIVE')
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
