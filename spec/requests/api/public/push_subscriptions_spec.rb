# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public push subscriptions', type: :request do
  let(:investor) { Investor.create!(name: 'Ana Pérez', email: 'ana@example.com', status: 'ACTIVE') }
  let(:endpoint) { 'https://fcm.googleapis.com/fcm/send/xyz' }
  let(:payload) do
    { email: investor.email, endpoint: endpoint, keys: { p256dh: 'p256', auth: 'auth' } }
  end

  around do |example|
    previous = ENV.to_h.slice('VAPID_PUBLIC_KEY', 'VAPID_PRIVATE_KEY')
    ENV['VAPID_PUBLIC_KEY'] = 'clave-publica'
    ENV['VAPID_PRIVATE_KEY'] = 'clave-privada'
    example.run
  ensure
    %w[VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY].each { |key| ENV[key] = previous[key] }
  end

  it 'GET /api/public/push/config devuelve la clave pública, nunca la privada' do
    get '/api/public/push/config'

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['data']).to eq('enabled' => true, 'publicKey' => 'clave-publica')
    expect(response.body).not_to include('clave-privada')
  end

  it 'GET /api/public/push/config avisa si no está configurado' do
    ENV['VAPID_PUBLIC_KEY'] = nil

    get '/api/public/push/config'

    expect(JSON.parse(response.body)['data']).to eq('enabled' => false, 'publicKey' => nil)
  end

  it 'POST /api/public/push/subscriptions guarda el dispositivo y no lo duplica' do
    2.times { post '/api/public/push/subscriptions', params: payload, as: :json }

    expect(response).to have_http_status(:created)
    expect(investor.push_subscriptions.count).to eq(1)
    expect(investor.push_subscriptions.first).to have_attributes(endpoint: endpoint, p256dh: 'p256', auth: 'auth')
  end

  it 'rechaza un inversor inexistente o inactivo' do
    post '/api/public/push/subscriptions', params: payload.merge(email: 'nadie@example.com'), as: :json
    expect(response).to have_http_status(:not_found)

    investor.update!(status: 'INACTIVE')
    post '/api/public/push/subscriptions', params: payload, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(PushSubscription.count).to eq(0)
  end

  it 'rechaza un endpoint que no es https' do
    post '/api/public/push/subscriptions', params: payload.merge(endpoint: 'http://ejemplo.com/x'), as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'DELETE /api/public/push/subscriptions desactiva el dispositivo' do
    post '/api/public/push/subscriptions', params: payload, as: :json

    delete '/api/public/push/subscriptions', params: { endpoint: endpoint }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(PushSubscription.count).to eq(0)
  end
end
