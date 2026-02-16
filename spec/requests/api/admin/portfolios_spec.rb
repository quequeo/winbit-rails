require 'rails_helper'

RSpec.describe 'Admin Portfolios API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345') }
  let!(:investor1) { Investor.create!(email: 'inv1@test.com', name: 'Investor 1', status: 'ACTIVE') }
  let!(:investor2) { Investor.create!(email: 'inv2@test.com', name: 'Investor 2', status: 'ACTIVE') }
  let!(:investor3) { Investor.create!(email: 'inv3@test.com', name: 'Investor 3', status: 'INACTIVE') }

  let!(:portfolio1) do
    Portfolio.create!(
      investor: investor1,
      current_balance: 10000,
      total_invested: 8000,
      accumulated_return_usd: 2000,
      accumulated_return_percent: 25.0,
      annual_return_usd: 1000,
      annual_return_percent: 12.5
    )
  end

  let!(:portfolio2) do
    Portfolio.create!(
      investor: investor2,
      current_balance: 5000,
      total_invested: 5000,
      accumulated_return_usd: 0,
      accumulated_return_percent: 0,
      annual_return_usd: 0,
      annual_return_percent: 0
    )
  end

  before do
    login_as(admin, scope: :user)
  end

  after do
    logout(:user)
  end

  describe 'GET /api/admin/portfolios' do
    it 'returns all active investors with portfolios' do
      get '/api/admin/portfolios'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data'].length).to eq(2) # Only ACTIVE investors
      expect(json['data'].first['id']).to be_present
      expect(json['data'].first['email']).to be_present
      expect(json['data'].first['name']).to be_present
      expect(json['data'].first['portfolio']).to be_present
    end

    it 'returns portfolios ordered by created_at desc' do
      get '/api/admin/portfolios'

      json = JSON.parse(response.body)
      expect(json['data'].first['id']).to eq(investor2.id)
      expect(json['data'].last['id']).to eq(investor1.id)
    end

    it 'includes null portfolio for investors without portfolio' do
      investor4 = Investor.create!(email: 'inv4@test.com', name: 'Investor 4', status: 'ACTIVE')

      get '/api/admin/portfolios'

      json = JSON.parse(response.body)
      investor4_data = json['data'].find { |inv| inv['id'] == investor4.id }

      expect(investor4_data).to be_present
      expect(investor4_data['portfolio']).to be_nil
    end
  end

  describe 'PATCH /api/admin/portfolios/:id' do
    it 'updates portfolio with all fields and auto-calculates accumulated returns' do
      patch "/api/admin/portfolios/#{investor1.id}", params: {
        currentBalance: 12000,
        totalInvested: 9000,
        annualReturnUSD: 1500,
        annualReturnPercent: 16.67
      }

      expect(response).to have_http_status(:no_content)

      portfolio1.reload
      expect(portfolio1.current_balance).to eq(12000)
      expect(portfolio1.total_invested).to eq(9000)
      # Accumulated returns are auto-calculated: 12000 - 9000 = 3000 USD, 33.33%
      expect(portfolio1.accumulated_return_usd).to eq(3000)
      expect(portfolio1.accumulated_return_percent).to be_within(0.01).of(33.33)
      expect(portfolio1.annual_return_usd).to eq(1500)
      expect(portfolio1.annual_return_percent).to eq(16.67)
    end

    it 'creates portfolio if it does not exist' do
      investor_without_portfolio = Investor.create!(
        email: 'no-portfolio@test.com',
        name: 'No Portfolio',
        status: 'ACTIVE'
      )

      expect(investor_without_portfolio.portfolio).to be_nil

      patch "/api/admin/portfolios/#{investor_without_portfolio.id}", params: {
        currentBalance: 5000,
        totalInvested: 5000,
        annualReturnUSD: 0,
        annualReturnPercent: 0
      }

      expect(response).to have_http_status(:no_content)

      investor_without_portfolio.reload
      expect(investor_without_portfolio.portfolio).to be_present
      expect(investor_without_portfolio.portfolio.current_balance).to eq(5000)
      # Accumulated returns should be auto-calculated to 0 (5000 - 5000)
      expect(investor_without_portfolio.portfolio.accumulated_return_usd).to eq(0)
      expect(investor_without_portfolio.portfolio.accumulated_return_percent).to eq(0)
    end

    it 'returns error when investor not found' do
      patch '/api/admin/portfolios/nonexistent', params: {
        currentBalance: 5000,
        totalInvested: 5000,
        annualReturnUSD: 0,
        annualReturnPercent: 0
      }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Inversor no encontrado')
    end

    it 'returns error when required params are missing' do
      patch "/api/admin/portfolios/#{investor1.id}", params: {
        currentBalance: 5000
        # Missing other required params
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error with invalid data' do
      patch "/api/admin/portfolios/#{investor1.id}", params: {
        currentBalance: -1000, # Negative value
        totalInvested: 5000,
        annualReturnUSD: 0,
        annualReturnPercent: 0
      }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
