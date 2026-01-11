require 'rails_helper'

RSpec.describe 'Api::Admin::Settings', type: :request do
  let(:user) { User.create!(email: 'admin@example.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  before do
    sign_in user, scope: :user

    # Reset settings
    AppSetting.where(key: [
      AppSetting::INVESTOR_NOTIFICATIONS_ENABLED,
      AppSetting::INVESTOR_EMAIL_WHITELIST
    ]).destroy_all
  end

  describe 'GET /api/admin/settings' do
    it 'returns default settings when not set' do
      get '/api/admin/settings'
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['investor_notifications_enabled']).to be false
      expect(json['data']['investor_email_whitelist']).to eq([])
    end

    it 'returns current settings' do
      AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'true')
      AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['test@example.com'])

      get '/api/admin/settings'
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['investor_notifications_enabled']).to be true
      expect(json['data']['investor_email_whitelist']).to eq(['test@example.com'])
    end
  end

  describe 'PATCH /api/admin/settings' do
    it 'updates notifications enabled setting' do
      patch '/api/admin/settings', params: {
        investor_notifications_enabled: true
      }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['investor_notifications_enabled']).to be true
      expect(AppSetting.investor_notifications_enabled?).to be true
    end

    it 'updates whitelist from array' do
      patch '/api/admin/settings', params: {
        investor_email_whitelist: ['test1@example.com', 'test2@example.com']
      }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['investor_email_whitelist']).to eq(['test1@example.com', 'test2@example.com'])
      expect(AppSetting.investor_email_whitelist).to eq(['test1@example.com', 'test2@example.com'])
    end

    it 'updates whitelist from comma-separated string' do
      patch '/api/admin/settings', params: {
        investor_email_whitelist: 'test1@example.com, test2@example.com'
      }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['investor_email_whitelist']).to eq(['test1@example.com', 'test2@example.com'])
    end

    it 'updates both settings at once' do
      patch '/api/admin/settings', params: {
        investor_notifications_enabled: true,
        investor_email_whitelist: ['test@example.com']
      }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['investor_notifications_enabled']).to be true
      expect(json['data']['investor_email_whitelist']).to eq(['test@example.com'])
    end

    it 'filters out empty emails from whitelist' do
      patch '/api/admin/settings', params: {
        investor_email_whitelist: 'test@example.com, , ,   '
      }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['investor_email_whitelist']).to eq(['test@example.com'])
    end
  end
end
