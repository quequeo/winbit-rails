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

  it 'GET /api/public/investor/:email/history includes tradingFeePercentage for TRADING_FEE' do
    investor = Investor.create!(email: 'fee@example.com', name: 'fee', status: 'ACTIVE')
    admin = User.create!(email: 'admin@example.com', name: 'Admin', role: 'ADMIN')

    # Create a TradingFee and a matching PortfolioHistory (within 10 minutes) so controller can attach metadata
    tf = TradingFee.create!(
      investor: investor,
      applied_by: admin,
      period_start: Date.new(2025, 10, 1),
      period_end: Date.new(2025, 12, 31),
      profit_amount: 1000,
      fee_percentage: 30,
      fee_amount: 300,
      applied_at: Time.utc(2026, 1, 22, 17, 0, 0)
    )

    PortfolioHistory.create!(
      investor_id: investor.id,
      date: tf.applied_at,
      event: 'TRADING_FEE',
      amount: -tf.fee_amount.to_f,
      previous_balance: 1000,
      new_balance: 700,
      status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    fee_item = json['data'].find { |it| it['event'] == 'TRADING_FEE' }
    expect(fee_item).to be_present
    expect(fee_item['tradingFeePeriodLabel']).to eq('Q4 2025')
    expect(fee_item['tradingFeePercentage']).to eq(30.0)
  end
end
