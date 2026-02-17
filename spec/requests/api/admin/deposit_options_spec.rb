require 'rails_helper'

RSpec.describe 'Admin Deposit Options API', type: :request do
  let!(:superadmin) { User.create!(email: 'super@test.com', name: 'Super Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345') }

  before { login_as(superadmin, scope: :user) }
  after { logout(:user) }

  let!(:option1) do
    DepositOption.create!(
      category: 'BANK_ARS', label: 'Banco Galicia', currency: 'ARS', position: 1,
      details: { 'bank_name' => 'Galicia', 'holder' => 'Winbit SRL', 'cbu_cvu' => '0070000' }
    )
  end

  let!(:option2) do
    DepositOption.create!(
      category: 'CRYPTO', label: 'USDT TRC20', currency: 'USDT', position: 2, active: false,
      details: { 'address' => 'TF7j33wo', 'network' => 'TRC20' }
    )
  end

  describe 'GET /api/admin/deposit_options' do
    it 'returns all deposit options ordered by position' do
      get '/api/admin/deposit_options'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(2)
      expect(json['data'][0]['label']).to eq('Banco Galicia')
      expect(json['data'][1]['label']).to eq('USDT TRC20')
    end

    it 'includes inactive options' do
      get '/api/admin/deposit_options'

      json = JSON.parse(response.body)
      labels = json['data'].map { |o| o['label'] }
      expect(labels).to include('USDT TRC20')
    end
  end

  describe 'POST /api/admin/deposit_options' do
    it 'creates a new deposit option' do
      post '/api/admin/deposit_options', params: {
        category: 'LEMON',
        label: 'Lemon Cash',
        currency: 'ARS',
        position: 3,
        details: { lemon_tag: '$winbit' },
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['category']).to eq('LEMON')
      expect(json['data']['details']['lemon_tag']).to eq('$winbit')
    end

    it 'returns 422 for invalid data' do
      post '/api/admin/deposit_options', params: {
        category: 'BANK_ARS',
        label: 'Banco',
        currency: 'ARS',
        details: {},
      }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('bank_name')
    end

    it 'returns 422 for missing category' do
      post '/api/admin/deposit_options', params: {
        label: 'Test',
        currency: 'ARS',
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/admin/deposit_options/:id' do
    it 'updates a deposit option' do
      patch "/api/admin/deposit_options/#{option1.id}", params: {
        label: 'Banco Galicia - Pesos',
        category: option1.category,
        currency: option1.currency,
        details: option1.details,
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['label']).to eq('Banco Galicia - Pesos')
    end

    it 'returns 404 for non-existent option' do
      patch '/api/admin/deposit_options/nonexistent', params: { label: 'Test' }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 for invalid update' do
      patch "/api/admin/deposit_options/#{option1.id}", params: {
        label: '',
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/admin/deposit_options/:id' do
    it 'deletes a deposit option' do
      delete "/api/admin/deposit_options/#{option2.id}"

      expect(response).to have_http_status(:no_content)
      expect(DepositOption.find_by(id: option2.id)).to be_nil
    end

    it 'returns 404 for non-existent option' do
      delete '/api/admin/deposit_options/nonexistent'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/admin/deposit_options/:id/toggle_active' do
    it 'toggles active from true to false' do
      post "/api/admin/deposit_options/#{option1.id}/toggle_active"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['active']).to be false
    end

    it 'toggles active from false to true' do
      post "/api/admin/deposit_options/#{option2.id}/toggle_active"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['active']).to be true
    end

    it 'returns 404 for non-existent option' do
      post '/api/admin/deposit_options/nonexistent/toggle_active'

      expect(response).to have_http_status(:not_found)
    end
  end
end
