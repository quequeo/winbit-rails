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
  end
end
