require 'rails_helper'

RSpec.describe 'Public Auth', type: :request do
  let!(:investor) do
    Investor.create!(
      email: 'client@example.com',
      name: 'Test Client',
      status: 'ACTIVE',
      password: 'secret123'
    )
  end

  before do
    allow(ENV).to receive(:[]).and_wrap_original do |method, key|
      key == 'INVESTOR_SHARED_LOGIN_PASSWORD' ? 'SharedLogin1' : method.call(key)
    end
  end

  describe 'POST /api/public/auth/login' do
    it 'returns investor data with valid credentials' do
      post '/api/public/auth/login', params: { email: 'client@example.com', password: 'secret123' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('investor', 'email')).to eq('client@example.com')
      expect(json.dig('investor', 'name')).to eq('Test Client')
    end

    it 'returns unauthorized with wrong password' do
      post '/api/public/auth/login', params: { email: 'client@example.com', password: 'wrong' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized with non-existent email' do
      post '/api/public/auth/login', params: { email: 'nobody@example.com', password: 'secret123' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns forbidden for inactive investor' do
      investor.update!(status: 'INACTIVE')

      post '/api/public/auth/login', params: { email: 'client@example.com', password: 'secret123' }

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns bad request when email or password is missing' do
      post '/api/public/auth/login', params: { email: 'client@example.com' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects password login for @gmail.com' do
      Investor.create!(
        email: 'guser@gmail.com',
        name: 'G User',
        status: 'ACTIVE',
        password: 'secret123',
      )

      post '/api/public/auth/login', params: { email: 'guser@gmail.com', password: 'secret123' }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Google')
    end

    it 'accepts shared login password for non-Gmail investors' do
      post '/api/public/auth/login', params: { email: 'client@example.com', password: 'SharedLogin1' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('investor', 'email')).to eq('client@example.com')
    end
  end

  describe 'POST /api/public/auth/change_password' do
    it 'changes password with valid current password' do
      post '/api/public/auth/change_password', params: {
        email: 'client@example.com',
        current_password: 'secret123',
        new_password: 'newpass456',
      }

      expect(response).to have_http_status(:ok)
      investor.reload
      expect(investor.authenticate('newpass456')).to be_truthy
    end

    it 'rejects change with wrong current password' do
      post '/api/public/auth/change_password', params: {
        email: 'client@example.com',
        current_password: 'wrong',
        new_password: 'newpass456',
      }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects short new password' do
      post '/api/public/auth/change_password', params: {
        email: 'client@example.com',
        current_password: 'secret123',
        new_password: 'abc',
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns bad request when fields are missing' do
      post '/api/public/auth/change_password', params: { email: 'client@example.com' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'allows changing password when current matches shared login password' do
      post '/api/public/auth/change_password', params: {
        email: 'client@example.com',
        current_password: 'SharedLogin1',
        new_password: 'newpass789',
      }

      expect(response).to have_http_status(:ok)
      investor.reload
      expect(investor.authenticate('newpass789')).to be_truthy
    end

    it 'rejects change_password for Gmail addresses' do
      Investor.create!(
        email: 'g@gmail.com',
        name: 'G',
        status: 'ACTIVE',
        password: 'secret123',
      )

      post '/api/public/auth/change_password', params: {
        email: 'g@gmail.com',
        current_password: 'secret123',
        new_password: 'newpass789',
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
