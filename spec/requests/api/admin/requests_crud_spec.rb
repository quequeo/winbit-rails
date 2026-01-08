require 'rails_helper'

RSpec.describe 'Admin Requests CRUD API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Test Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000) }

  before do
    login_as(admin, scope: :user)
  end

  after do
    logout(:user)
  end

  describe 'POST /api/admin/requests' do
    it 'creates a new request with valid params' do
      post '/api/admin/requests', params: {
        investor_id: investor.id,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 500,
        network: 'TRC20',
        status: 'PENDING'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to be_present

      request = InvestorRequest.find(json['data']['id'])
      expect(request.investor_id).to eq(investor.id)
      expect(request.request_type).to eq('DEPOSIT')
      expect(request.method).to eq('USDT')
      expect(request.amount).to eq(500)
      expect(request.network).to eq('TRC20')
      expect(request.status).to eq('PENDING')
    end

    it 'defaults status to PENDING if not provided' do
      post '/api/admin/requests', params: {
        investor_id: investor.id,
        request_type: 'WITHDRAWAL',
        method: 'USDC',
        amount: 200
      }

      expect(response).to have_http_status(:created)
      request = InvestorRequest.last
      expect(request.status).to eq('PENDING')
    end

    it 'returns error when investor not found' do
      post '/api/admin/requests', params: {
        investor_id: 'nonexistent',
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 500
      }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Inversor no encontrado')
    end

    it 'returns error when required params are missing' do
      post '/api/admin/requests', params: {
        investor_id: investor.id,
        request_type: 'DEPOSIT'
        # missing method and amount
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error with invalid request_type' do
      post '/api/admin/requests', params: {
        investor_id: investor.id,
        request_type: 'INVALID',
        method: 'USDT',
        amount: 500
      }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to be_present
    end

    it 'returns error with invalid method' do
      post '/api/admin/requests', params: {
        investor_id: investor.id,
        request_type: 'DEPOSIT',
        method: 'BITCOIN',
        amount: 500
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error with negative amount' do
      post '/api/admin/requests', params: {
        investor_id: investor.id,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: -100
      }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'PATCH /api/admin/requests/:id' do
    let!(:request_record) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 500,
        status: 'PENDING',
        requested_at: Time.current
      )
    end

    it 'updates request with valid params' do
      patch "/api/admin/requests/#{request_record.id}", params: {
        investor_id: investor.id,
        request_type: 'WITHDRAWAL',
        method: 'USDC',
        amount: 300,
        network: 'BEP20',
        status: 'APPROVED'
      }

      expect(response).to have_http_status(:no_content)

      request_record.reload
      expect(request_record.request_type).to eq('WITHDRAWAL')
      expect(request_record.method).to eq('USDC')
      expect(request_record.amount).to eq(300)
      expect(request_record.network).to eq('BEP20')
      expect(request_record.status).to eq('APPROVED')
    end

    it 'returns error when request not found' do
      patch '/api/admin/requests/nonexistent', params: {
        investor_id: investor.id,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 500
      }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error with invalid params' do
      patch "/api/admin/requests/#{request_record.id}", params: {
        investor_id: investor.id,
        request_type: 'INVALID_TYPE',
        method: 'USDT',
        amount: 500
      }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'DELETE /api/admin/requests/:id' do
    let!(:request_record) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 500,
        status: 'PENDING',
        requested_at: Time.current
      )
    end

    it 'deletes the request' do
      request_id = request_record.id

      delete "/api/admin/requests/#{request_id}"

      expect(response).to have_http_status(:no_content)
      expect(InvestorRequest.find_by(id: request_id)).to be_nil
    end

    it 'returns error when request not found' do
      delete '/api/admin/requests/nonexistent'

      expect(response).to have_http_status(:not_found)
    end
  end
end
