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

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns bad request when fields are missing' do
      post '/api/public/auth/change_password', params: { email: 'client@example.com' }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
