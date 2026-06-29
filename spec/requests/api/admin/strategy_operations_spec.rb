require 'rails_helper'

RSpec.describe 'Admin strategy operations', type: :request do
  let!(:admin) do
    User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '1')
  end

  before { login_as(admin, scope: :user) }

  after { logout(:user) }

  describe 'GET /api/admin/v1/strategy_operations' do
    it 'returns operations list' do
      StrategyOperation.create!(
        operation_date: Date.new(2026, 5, 4),
        asset: 'MNQ',
        result_label: 'POSITIVO',
        opened_at: '12:08',
        closed_at: '12:10',
        created_by: admin,
        source: 'manual',
      )

      get '/api/admin/v1/strategy_operations'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json['data'].first['asset']).to eq('MNQ')
    end
  end

  describe 'POST /api/admin/v1/strategy_operations' do
    it 'creates a manual operation' do
      post '/api/admin/v1/strategy_operations',
           params: {
             operation_date: '2026-05-04',
             asset: 'MES',
             direction: 'LONG',
             result_label: 'POSITIVO',
           },
           as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'asset')).to eq('MES')
      expect(json.dig('data', 'source')).to eq('manual')
    end
  end
end
