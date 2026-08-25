require 'rails_helper'

RSpec.describe 'Public strategy operations', type: :request do
  let!(:admin) do
    User.create!(email: 'admin-public-ops@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'pub-ops')
  end

  it 'GET /api/public/v1/strategy_operations returns operations' do
    StrategyOperation.create!(
      operation_date: Date.new(2026, 6, 26),
      asset: 'MNQ',
      direction: 'SHORT',
      opened_at: '11:19',
      closed_at: '11:26',
      ratio: 1.01,
      created_by: admin,
      source: 'manual',
    )

    get '/api/public/v1/strategy_operations'

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(1)
    expect(json['data'].first['asset']).to eq('MNQ')
    expect(json['data'].first['openedAt']).to eq('11:19')
    expect(json['data'].first['ratio']).to eq(1.01)
  end
end
