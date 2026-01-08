require 'rails_helper'

RSpec.describe 'Admin Session API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }
  let!(:superadmin) { User.create!(email: 'super@test.com', name: 'Super Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '67890') }

  describe 'GET /api/admin/session' do
    context 'when logged in as admin' do
      before do
        login_as(admin, scope: :user)
      end

      after do
        logout(:user)
      end

      it 'returns current user session data' do
        get '/api/admin/session'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']['email']).to eq('admin@test.com')
        expect(json['data']['superadmin']).to be false
      end
    end

    context 'when logged in as superadmin' do
      before do
        login_as(superadmin, scope: :user)
      end

      after do
        logout(:user)
      end

      it 'returns superadmin flag as true' do
        get '/api/admin/session'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']['email']).to eq('super@test.com')
        expect(json['data']['superadmin']).to be true
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/admin/session'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
