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

  it 'renders target display for common target types' do
    inv = Investor.create!(email: 'inv2@test.com', name: 'Inv2', status: 'ACTIVE')
    portfolio = Portfolio.create!(investor: inv, current_balance: 10, total_invested: 10)
    req = InvestorRequest.create!(
      investor: inv,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 50,
      status: 'PENDING',
      requested_at: Time.current
    )
    setting = AppSetting.set('investor_notifications_enabled', 'true', description: 'x')

    ActivityLogger.log(user: admin, target: inv, action: 'update_investor', metadata: {})
    ActivityLogger.log(user: admin, target: portfolio, action: 'update_portfolio', metadata: {})
    ActivityLogger.log(user: admin, target: req, action: 'approve_request', metadata: {})
    ActivityLogger.log(user: admin, target: admin, action: 'update_admin', metadata: {})
    ActivityLogger.log(user: admin, target: setting, action: 'update_settings', metadata: {})

    login_as(admin, scope: :user)
    get '/api/admin/activity_logs', params: { page: 1, per_page: 50 }
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    displays = json['data']['logs'].map { |l| l.dig('target', 'display') }

    # Investor display uses email when target exists
    expect(displays.join(' ')).to include('inv2@test.com')
    expect(displays.join(' ')).to include('Portfolio de Inv2')
    expect(displays.join(' ')).to include('DEPOSIT')
    expect(displays.join(' ')).to include('Admin')
    expect(displays.join(' ')).to include('Notificaciones')
  end
end
