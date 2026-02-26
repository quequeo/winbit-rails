require 'rails_helper'

RSpec.describe 'Admin Investors API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345') }

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

    it 'supports sorting by status' do
      Investor.create!(email: 'active@test.com', name: 'Active', status: 'ACTIVE')
      Investor.create!(email: 'inactive@test.com', name: 'Inactive', status: 'INACTIVE')

      get '/api/admin/investors', params: { sort_by: 'status', sort_order: 'asc' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].size).to be >= 2
    end

    it 'supports sorting by created_at asc when sort_by is omitted' do
      older = Investor.create!(email: 'older@test.com', name: 'Older', status: 'ACTIVE', created_at: 2.days.ago)
      newer = Investor.create!(email: 'newer@test.com', name: 'Newer', status: 'ACTIVE', created_at: 1.day.ago)

      get '/api/admin/investors', params: { sort_order: 'asc' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      ids = json['data'].map { |it| it['id'] }
      expect(ids.index(older.id)).to be < ids.index(newer.id)
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
      expect(investor.trading_fee_percentage.to_f).to eq(30.0)
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

    it 'updates investor status from edit endpoint' do
      patch "/api/admin/investors/#{investor.id}", params: {
        email: investor.email,
        name: investor.name,
        status: 'INACTIVE',
        trading_fee_percentage: 25
      }

      expect(response).to have_http_status(:no_content)
      investor.reload
      expect(investor.status).to eq('INACTIVE')
      expect(investor.trading_fee_percentage.to_f).to eq(25.0)
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

  describe 'POST /api/admin/investors/:id/referral_commissions' do
    let(:investor) { Investor.create!(email: 'ref@test.com', name: 'Ref Investor', status: 'ACTIVE') }
    let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 500, total_invested: 500) }

    it 'applies referral commission and returns new balance' do
      post "/api/admin/investors/#{investor.id}/referral_commissions",
           params: { amount: 50 }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['current_balance']).to eq(550.0)
      expect(json['data']['investor_id']).to eq(investor.id)

      portfolio.reload
      expect(portfolio.current_balance).to eq(550)
    end

    it 'returns unprocessable when applicator fails' do
      post "/api/admin/investors/#{investor.id}/referral_commissions",
           params: { amount: -10 }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to be_present
    end

    it 'returns error when amount is missing' do
      post "/api/admin/investors/#{investor.id}/referral_commissions", params: {}

      expect(response).to have_http_status(:bad_request)
    end

    it 'supports backfilling with applied_at when future history exists' do
      PortfolioHistory.create!(
        investor: investor,
        date: 2.days.ago,
        event: 'DEPOSIT',
        amount: 200,
        previous_balance: 0,
        new_balance: 200,
        status: 'COMPLETED'
      )
      PortfolioHistory.create!(
        investor: investor,
        date: 1.day.from_now,
        event: 'WITHDRAWAL',
        amount: 50,
        previous_balance: 200,
        new_balance: 150,
        status: 'COMPLETED'
      )
      portfolio.update!(current_balance: 150)

      post "/api/admin/investors/#{investor.id}/referral_commissions",
           params: { amount: 25, applied_at: 1.day.ago.to_date.strftime('%Y-%m-%d') }

      expect(response).to have_http_status(:created)
      portfolio.reload
      expect(portfolio.current_balance).to eq(175.0)
    end
  end

  describe 'DELETE /api/admin/investors/:id' do
    let(:investor) { Investor.create!(email: 'delete@test.com', name: 'To Delete', status: 'ACTIVE') }

    it 'deletes the investor and associated records' do
      investor_id = investor.id
      Portfolio.create!(investor: investor, current_balance: 500)
      TradingFee.create!(
        investor: investor,
        applied_by: admin,
        period_start: Date.new(2025, 10, 1),
        period_end: Date.new(2025, 12, 31),
        profit_amount: 100,
        fee_percentage: 30,
        fee_amount: 30,
        applied_at: Time.current
      )

      delete "/api/admin/investors/#{investor_id}"

      expect(response).to have_http_status(:no_content)
      expect(Investor.find_by(id: investor_id)).to be_nil
      expect(Portfolio.find_by(investor_id: investor_id)).to be_nil
      expect(TradingFee.where(investor_id: investor_id)).to be_empty
    end

    it 'returns error when investor not found' do
      delete '/api/admin/investors/nonexistent-id'

      expect(response).to have_http_status(:not_found)
    end
  end
end
