require 'rails_helper'

RSpec.describe 'Public investors', type: :request do
  it 'GET /api/public/investor/:email returns investor + portfolio' do
    investor = Investor.create!(email: 'test@example.com', name: 'juan perez', status: 'ACTIVE')
    Portfolio.create!(
      investor_id: investor.id,
      current_balance: 100,
      total_invested: 80,
      accumulated_return_usd: 20,
      accumulated_return_percent: 25,
      annual_return_usd: 10,
      annual_return_percent: 12.5
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}"

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'investor', 'email')).to eq('test@example.com')
    expect(json.dig('data', 'investor', 'name')).to eq('Juan Perez')
    expect(json.dig('data', 'portfolio', 'currentBalance')).to eq(100.0)
  end

  it 'GET /api/public/investor/:email returns 404 when missing' do
    get "/api/public/investor/#{CGI.escape('missing@example.com')}"
    expect(response).to have_http_status(:not_found)
  end

  it 'GET /api/public/investor/:email returns 403 when inactive' do
    Investor.create!(email: 'inactive@example.com', name: 'x', status: 'INACTIVE')

    get "/api/public/investor/#{CGI.escape('inactive@example.com')}"
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /api/public/investor/:email/history returns history desc' do
    investor = Investor.create!(email: 'h@example.com', name: 'h', status: 'ACTIVE')

    PortfolioHistory.create!(
      investor_id: investor.id,
      date: Time.utc(2024, 2, 1),
      event: 'DEPOSIT',
      amount: 100,
      previous_balance: 0,
      new_balance: 100,
      status: 'COMPLETED'
    )
    PortfolioHistory.create!(
      investor_id: investor.id,
      date: Time.utc(2024, 3, 1),
      event: 'WITHDRAWAL',
      amount: 10,
      previous_balance: 100,
      new_balance: 90,
      status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(2)
    expect(json['data'][0]['event']).to eq('WITHDRAWAL')
    expect(json['data'][1]['event']).to eq('DEPOSIT')
  end
end
