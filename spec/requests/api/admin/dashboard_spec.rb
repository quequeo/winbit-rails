require 'rails_helper'

RSpec.describe 'Admin Dashboard API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }
  let!(:investor1) { Investor.create!(email: 'inv1@test.com', name: 'Investor 1', status: 'ACTIVE') }
  let!(:investor2) { Investor.create!(email: 'inv2@test.com', name: 'Investor 2', status: 'ACTIVE') }
  let!(:investor3) { Investor.create!(email: 'inv3@test.com', name: 'Investor 3', status: 'INACTIVE') }

  let!(:portfolio1) { Portfolio.create!(investor: investor1, current_balance: 10000, total_invested: 10000) }
  let!(:portfolio2) { Portfolio.create!(investor: investor2, current_balance: 5000, total_invested: 5000) }

  let!(:request1) do
    InvestorRequest.create!(
      investor: investor1,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 1000,
      status: 'PENDING',
      requested_at: Time.current
    )
  end

  let!(:request2) do
    InvestorRequest.create!(
      investor: investor2,
      request_type: 'WITHDRAWAL',
      method: 'USDC',
      amount: 500,
      status: 'APPROVED',
      requested_at: Time.current
    )
  end

  before do
    login_as(admin, scope: :user)
  end

  after do
    logout(:user)
  end

  describe 'GET /api/admin/dashboard' do
    it 'returns dashboard statistics' do
      get '/api/admin/dashboard'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['investorCount']).to eq(2) # Only ACTIVE investors
      expect(json['data']['pendingRequestCount']).to eq(1)
      expect(json['data']['totalAum']).to eq(15000.0) # Sum of all portfolios
      expect(json['data']['aumSeries']).to be_an(Array)
      expect(json['data']['aumSeries'].length).to be >= 7
      expect(json['data']['aumSeries'].last['totalAum']).to eq(15000.0)

      expect(json['data']['strategyReturnYtdUsd']).to be_a(Numeric)
      expect(json['data']['strategyReturnYtdPercent']).to be_a(Numeric)
      expect(json['data']['strategyReturnAllUsd']).to be_a(Numeric)
      expect(json['data']['strategyReturnAllPercent']).to be_a(Numeric)
    end

    it 'clamps days to min 7 when days is too small' do
      get '/api/admin/dashboard', params: { days: 3 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['aumSeries'].length).to eq(7)
    end

    it 'clamps days to max 365 when days is too large' do
      get '/api/admin/dashboard', params: { days: 1000 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['aumSeries'].length).to eq(365)
    end

    it 'uses earliest movement date when days=0 (all-time) and series grows accordingly' do
      # Create a history so "days=0" starts from the earliest movement date.
      PortfolioHistory.create!(
        investor: investor1,
        event: 'DEPOSIT',
        amount: 0,
        previous_balance: 0,
        new_balance: 10_000,
        status: 'COMPLETED',
        date: 10.days.ago
      )

      get '/api/admin/dashboard', params: { days: 0 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['aumSeries'].length).to be >= 11
    end

    it 'returns aumSeries based on PortfolioHistory when movements exist' do
      start = Date.current - 2
      # Before range: sets initial balance at range start
      PortfolioHistory.create!(
        investor: investor1,
        event: 'DEPOSIT',
        amount: 10_000,
        previous_balance: 0,
        new_balance: 10_000,
        status: 'COMPLETED',
        date: Time.zone.local(start.year, start.month, start.day, 19, 0, 0) - 1.day
      )
      # Inside range: increase
      PortfolioHistory.create!(
        investor: investor1,
        event: 'OPERATING_RESULT',
        amount: 500,
        previous_balance: 10_000,
        new_balance: 10_500,
        status: 'COMPLETED',
        date: Time.zone.local(start.year, start.month, start.day, 17, 0, 0)
      )

      get '/api/admin/dashboard', params: { days: 7 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['aumSeries']).to be_an(Array)
    end

    it 'returns zero counts when no data exists' do
      Investor.destroy_all
      Portfolio.destroy_all
      InvestorRequest.destroy_all

      get '/api/admin/dashboard'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['investorCount']).to eq(0)
      expect(json['data']['pendingRequestCount']).to eq(0)
      expect(json['data']['totalAum']).to eq(0.0)
      expect(json['data']['aumSeries']).to be_an(Array)
      expect(json['data']['aumSeries'].length).to be >= 7
      expect(json['data']['aumSeries'].last['totalAum']).to eq(0.0)

      expect(json['data']['strategyReturnYtdUsd']).to be_a(Numeric)
      expect(json['data']['strategyReturnYtdPercent']).to be_a(Numeric)
      expect(json['data']['strategyReturnAllUsd']).to be_a(Numeric)
      expect(json['data']['strategyReturnAllPercent']).to be_a(Numeric)
    end

    it 'only counts ACTIVE investors' do
      get '/api/admin/dashboard'

      json = JSON.parse(response.body)
      expect(json['data']['investorCount']).to eq(2) # investor3 is INACTIVE
    end

    it 'only counts PENDING requests' do
      get '/api/admin/dashboard'

      json = JSON.parse(response.body)
      expect(json['data']['pendingRequestCount']).to eq(1) # request2 is APPROVED
    end

    it 'excludes inactive investors from strategy return calculations' do
      Portfolio.create!(investor: investor3, current_balance: 0, total_invested: 0)

      PortfolioHistory.create!(
        investor: investor1,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 0,
        new_balance: 1000,
        status: 'COMPLETED',
        date: Time.zone.local(2026, 1, 10, 19, 0, 0)
      )
      PortfolioHistory.create!(
        investor: investor1,
        event: 'OPERATING_RESULT',
        amount: 100,
        previous_balance: 1000,
        new_balance: 1100,
        status: 'COMPLETED',
        date: Time.zone.local(2026, 1, 12, 17, 0, 0)
      )

      PortfolioHistory.create!(
        investor: investor3,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 0,
        new_balance: 1000,
        status: 'COMPLETED',
        date: Time.zone.local(2026, 1, 10, 19, 0, 0)
      )
      PortfolioHistory.create!(
        investor: investor3,
        event: 'OPERATING_RESULT',
        amount: 900,
        previous_balance: 1000,
        new_balance: 1900,
        status: 'COMPLETED',
        date: Time.zone.local(2026, 1, 12, 17, 0, 0)
      )

      get '/api/admin/dashboard', params: { days: 30 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['strategyReturnAllUsd']).to be_within(0.01).of(100.0)
      expect(json['data']['strategyReturnAllPercent']).to be_within(0.0001).of(10.0)
    end
  end
end
