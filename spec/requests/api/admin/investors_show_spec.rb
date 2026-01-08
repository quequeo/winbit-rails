require 'rails_helper'

RSpec.describe 'Admin Investors Show API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Test Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 10000, total_invested: 8000) }

  before do
    login_as(admin, scope: :user)
  end

  after do
    logout(:user)
  end

  describe 'GET /api/admin/investors/:id' do
    it 'returns a specific investor with portfolio' do
      get "/api/admin/investors/#{investor.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['id']).to eq(investor.id)
      expect(json['data']['email']).to eq('inv@test.com')
      expect(json['data']['name']).to eq('Test Investor')
      expect(json['data']['status']).to eq('ACTIVE')
      expect(json['data']['portfolio']).to be_present
      expect(json['data']['portfolio']['current_balance']).to eq('10000.0')
    end

    it 'returns error when investor not found' do
      get '/api/admin/investors/nonexistent'

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to include('no encontrado')
    end

    it 'returns investor without portfolio' do
      investor_no_port = Investor.create!(email: 'noport@test.com', name: 'No Portfolio', status: 'ACTIVE')

      get "/api/admin/investors/#{investor_no_port.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['id']).to eq(investor_no_port.id)
      expect(json['data']['portfolio']).to be_nil
    end

    it 'returns inactive investor' do
      inactive = Investor.create!(email: 'inactive@test.com', name: 'Inactive', status: 'INACTIVE')

      get "/api/admin/investors/#{inactive.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['status']).to eq('INACTIVE')
    end
  end
end
