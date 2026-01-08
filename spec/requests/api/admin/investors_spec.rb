require 'rails_helper'

RSpec.describe 'Admin Investors API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  before do
    # Simulate logged in user with Warden
    login_as(admin, scope: :user)
  end

  after do
    logout(:user)
  end

  describe 'GET /api/admin/investors' do
    it 'returns all investors with portfolios' do
      inv1 = Investor.create!(email: 'inv1@test.com', name: 'Investor One', status: 'ACTIVE')
      Portfolio.create!(investor: inv1, current_balance: 1000)

      inv2 = Investor.create!(email: 'inv2@test.com', name: 'Investor Two', status: 'INACTIVE')

      get '/api/admin/investors'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(2)
      expect(json['data'].first['email']).to be_present
      expect(json['data'].first['name']).to be_present
      expect(json['data'].first['status']).to be_in(['ACTIVE', 'INACTIVE'])
    end

    it 'supports sorting by name' do
      Investor.create!(email: 'b@test.com', name: 'Beta', status: 'ACTIVE')
      Investor.create!(email: 'a@test.com', name: 'Alpha', status: 'ACTIVE')

      get '/api/admin/investors', params: { sort_by: 'name', sort_order: 'asc' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].first['name']).to eq('Alpha')
      expect(json['data'].last['name']).to eq('Beta')
    end

    it 'supports sorting by balance' do
      inv1 = Investor.create!(email: 'low@test.com', name: 'Low Balance', status: 'ACTIVE')
      Portfolio.create!(investor: inv1, current_balance: 100)

      inv2 = Investor.create!(email: 'high@test.com', name: 'High Balance', status: 'ACTIVE')
      Portfolio.create!(investor: inv2, current_balance: 1000)

      get '/api/admin/investors', params: { sort_by: 'balance', sort_order: 'desc' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].first['portfolio']['currentBalance']).to eq(1000.0)
      expect(json['data'].last['portfolio']['currentBalance']).to eq(100.0)
    end
  end

  describe 'POST /api/admin/investors' do
    it 'creates a new investor with portfolio' do
      post '/api/admin/investors', params: {
        email: 'new@test.com',
        name: 'New Investor'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to be_present

      investor = Investor.find(json['data']['id'])
      expect(investor.email).to eq('new@test.com')
      expect(investor.name).to eq('New Investor')
      expect(investor.status).to eq('ACTIVE')
      expect(investor.portfolio).to be_present
      expect(investor.portfolio.current_balance).to eq(0)
    end

    it 'returns error when email is missing' do
      post '/api/admin/investors', params: { name: 'No Email' }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to be_present
    end

    it 'returns error when email is duplicate' do
      Investor.create!(email: 'duplicate@test.com', name: 'First', status: 'ACTIVE')

      post '/api/admin/investors', params: {
        email: 'duplicate@test.com',
        name: 'Second'
      }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Email')
    end

    it 'returns error when name is missing' do
      post '/api/admin/investors', params: { email: 'noname@test.com' }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to be_present
    end
  end

  describe 'PATCH /api/admin/investors/:id' do
    let(:investor) { Investor.create!(email: 'original@test.com', name: 'Original Name', status: 'ACTIVE') }

    it 'updates investor email and name' do
      patch "/api/admin/investors/#{investor.id}", params: {
        email: 'updated@test.com',
        name: 'Updated Name'
      }

      expect(response).to have_http_status(:no_content)

      investor.reload
      expect(investor.email).to eq('updated@test.com')
      expect(investor.name).to eq('Updated Name')
    end

    it 'returns error when investor not found' do
      patch '/api/admin/investors/nonexistent-id', params: {
        email: 'test@test.com',
        name: 'Test'
      }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error when email is duplicate' do
      other = Investor.create!(email: 'other@test.com', name: 'Other', status: 'ACTIVE')

      patch "/api/admin/investors/#{investor.id}", params: {
        email: 'other@test.com',
        name: 'Trying to duplicate'
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error when email is missing' do
      patch "/api/admin/investors/#{investor.id}", params: { name: 'Only Name' }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /api/admin/investors/:id/toggle_status' do
    let(:investor) { Investor.create!(email: 'toggle@test.com', name: 'Toggle Test', status: 'ACTIVE') }

    it 'toggles status from ACTIVE to INACTIVE' do
      post "/api/admin/investors/#{investor.id}/toggle_status"

      expect(response).to have_http_status(:no_content)
      investor.reload
      expect(investor.status).to eq('INACTIVE')
    end

    it 'toggles status from INACTIVE to ACTIVE' do
      investor.update!(status: 'INACTIVE')

      post "/api/admin/investors/#{investor.id}/toggle_status"

      expect(response).to have_http_status(:no_content)
      investor.reload
      expect(investor.status).to eq('ACTIVE')
    end

    it 'returns error when investor not found' do
      post '/api/admin/investors/nonexistent/toggle_status'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/admin/investors/:id' do
    let(:investor) { Investor.create!(email: 'delete@test.com', name: 'To Delete', status: 'ACTIVE') }

    it 'deletes the investor and associated records' do
      investor_id = investor.id
      Portfolio.create!(investor: investor, current_balance: 500)

      delete "/api/admin/investors/#{investor_id}"

      expect(response).to have_http_status(:no_content)
      expect(Investor.find_by(id: investor_id)).to be_nil
      expect(Portfolio.find_by(investor_id: investor_id)).to be_nil
    end

    it 'returns error when investor not found' do
      delete '/api/admin/investors/nonexistent-id'

      expect(response).to have_http_status(:not_found)
    end
  end
end
