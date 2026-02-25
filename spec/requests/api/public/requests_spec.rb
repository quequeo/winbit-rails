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

  it 'POST /api/public/requests returns 400 when email is blank' do
    post '/api/public/requests',
         params: {
           email: '',
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_ARS'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Email is required')
  end

  it 'POST /api/public/requests returns 400 when email format is invalid' do
    post '/api/public/requests',
         params: {
           email: 'not-an-email',
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_ARS'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid email format')
  end

  it 'POST /api/public/requests returns 400 when withdrawal has no portfolio' do
    investor = Investor.create!(email: 'nop@example.com', name: 'nop', status: 'ACTIVE')

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 10,
           method: 'USDT'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('No portfolio found')
  end

  it 'POST /api/public/requests returns 400 with details when validation fails' do
    investor = Investor.create!(email: 'val@example.com', name: 'inv', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_ARS',
           network: 'INVALID_NETWORK'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid request data')
    expect(json['details']).to be_present
    expect(json['details']['network']).to be_present
  end

  it 'POST /api/public/requests returns 400 when amount is invalid' do
    investor = Investor.create!(email: 'inv@example.com', name: 'inv', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: -10,
           method: 'CASH_ARS'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid request data')
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
