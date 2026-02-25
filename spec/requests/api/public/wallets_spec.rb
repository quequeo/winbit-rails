require 'rails_helper'

RSpec.describe 'Public wallets', type: :request do
  it 'GET /api/public/wallets returns empty array when no wallets exist' do
    get '/api/public/wallets'

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data']).to eq([])
  end

  it 'GET /api/public/wallets returns enabled wallets only' do
    Wallet.create!(asset: 'USDT', network: 'TRC20', address: 'addr1', enabled: true)
    Wallet.create!(asset: 'USDC', network: 'ERC20', address: 'addr2', enabled: false)

    get '/api/public/wallets'

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(1)
    expect(json['data'][0]['asset']).to eq('USDT')
    expect(json['data'][0]['network']).to eq('TRC20')
  end
end
