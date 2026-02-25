require 'rails_helper'

RSpec.describe 'Admin Auth API', type: :request do
  let!(:admin) do
    user = User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345')
    user.update!(password: 'secret123')
    user
  end

  describe 'POST /api/admin/auth/login' do
    it 'returns session data with valid credentials' do
      post '/api/admin/auth/login', params: { email: 'admin@test.com', password: 'secret123' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'email')).to eq('admin@test.com')
    end

    it 'returns unauthorized with wrong password' do
      post '/api/admin/auth/login', params: { email: 'admin@test.com', password: 'wrong' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized with non-existent email' do
      post '/api/admin/auth/login', params: { email: 'nobody@test.com', password: 'secret123' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'strips and downcases email before lookup' do
      post '/api/admin/auth/login', params: { email: '  Admin@Test.com  ', password: 'secret123' }

      expect(response).to have_http_status(:ok)
    end
  end
end
