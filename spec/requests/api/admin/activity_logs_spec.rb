require 'rails_helper'

RSpec.describe 'Admin Activity Logs API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  it 'lists activity logs with pagination and supports filter_action' do
    inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')

    ActivityLogger.log(user: admin, target: inv, action: 'create_investor', metadata: { amount: 1 })
    ActivityLogger.log(user: admin, target: inv, action: 'update_investor', metadata: { amount: 2 })

    login_as(admin, scope: :user)
    get '/api/admin/activity_logs', params: { page: 1, per_page: 50 }

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data']['logs']).to be_an(Array)
    expect(json['data']['pagination']['total']).to be >= 2

    login_as(admin, scope: :user)
    get '/api/admin/activity_logs', params: { filter_action: 'update_investor' }

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    actions = json['data']['logs'].map { |l| l['action'] }
    expect(actions.uniq).to eq(['update_investor'])

    logout(:user)
  end
end
