require 'rails_helper'

RSpec.describe 'Public payment methods', type: :request do
  before do
    PaymentMethod.find_or_create_by!(code: 'LEMON_CASH') do |pm|
      pm.name = 'Lemon Cash'
      pm.kind = 'FIAT'
      pm.enabled_for_deposit = true
      pm.enabled_for_withdrawal = true
      pm.requires_lemontag = true
      pm.position = 40
    end
    PaymentMethod.find_or_create_by!(code: 'CRYPTO') do |pm|
      pm.name = 'Criptomonedas'
      pm.kind = 'CRYPTO'
      pm.enabled_for_deposit = true
      pm.enabled_for_withdrawal = true
      pm.requires_network = true
      pm.position = 10
    end
  end

  it 'GET /api/public/payment_methods returns withdrawal methods' do
    get '/api/public/payment_methods', params: { flow: 'withdrawal' }

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    codes = json['data'].map { |row| row['code'] }
    expect(codes).to include('LEMON_CASH', 'CRYPTO')
    lemon = json['data'].find { |row| row['code'] == 'LEMON_CASH' }
    expect(lemon['requiresLemontag']).to be(true)
  end

  it 'returns 400 for invalid flow' do
    get '/api/public/payment_methods', params: { flow: 'invalid' }
    expect(response).to have_http_status(:bad_request)
  end
end
