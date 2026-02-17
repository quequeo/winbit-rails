require 'rails_helper'

RSpec.describe 'Admin Daily Operating Results API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345') }

  before do
    login_as(admin, scope: :user)
  end

  after do
    logout(:user)
  end

  def create_investor_with_balance(balance:, at_time:)
    inv = Investor.create!(email: "inv-#{SecureRandom.hex(4)}@test.com", name: 'Inv', status: 'ACTIVE')
    Portfolio.create!(investor: inv, current_balance: balance, total_invested: balance)

    # Seed a history before at_time so applicator sees balance > 0 at that date
    PortfolioHistory.create!(
      investor: inv,
      event: 'DEPOSIT',
      amount: balance,
      previous_balance: 0,
      new_balance: balance,
      status: 'COMPLETED',
      date: at_time - 1.hour,
    )

    inv
  end

  describe 'GET /api/admin/daily_operating_results' do
    it 'returns paginated results with meta' do
      DailyOperatingResult.create!(date: Date.new(2025, 6, 2), percent: 0.1, applied_by: admin, applied_at: Time.current)
      DailyOperatingResult.create!(date: Date.new(2025, 6, 1), percent: -0.1, applied_by: admin, applied_at: Time.current)

      get '/api/admin/daily_operating_results', params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(1)
      expect(json['meta']['page']).to eq(1)
      expect(json['meta']['per_page']).to eq(1)
      expect(json['meta']['total']).to eq(2)
    end

    it 'includes notes in list payload' do
      DailyOperatingResult.create!(
        date: Date.new(2025, 6, 3),
        percent: 0.2,
        notes: 'Operativa con volatilidad alta',
        applied_by: admin,
        applied_at: Time.current
      )

      get '/api/admin/daily_operating_results'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].first['notes']).to eq('Operativa con volatilidad alta')
    end
  end

  describe 'GET /api/admin/daily_operating_results/monthly_summary' do
    it 'returns months including empty months (compounded 0, days 0)' do
      # Create a single day in current month so summary isn't all zeros
      today = Date.current
      DailyOperatingResult.create!(date: today, percent: 0.1, applied_by: admin, applied_at: Time.current)

      get '/api/admin/daily_operating_results/monthly_summary', params: { months: 6 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(6)
      expect(json['data'].first).to have_key('month')
      expect(json['data'].first).to have_key('days')
      expect(json['data'].first).to have_key('compounded_percent')
    end
  end

  describe 'GET /api/admin/daily_operating_results/by_month' do
    it 'returns 422 for invalid month param' do
      get '/api/admin/daily_operating_results/by_month', params: { month: '2025-13' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns results ordered desc for that month' do
      DailyOperatingResult.create!(date: Date.new(2025, 6, 2), percent: 0.1, notes: 'Segundo día', applied_by: admin, applied_at: Time.current)
      DailyOperatingResult.create!(date: Date.new(2025, 6, 1), percent: -0.1, applied_by: admin, applied_at: Time.current)

      get '/api/admin/daily_operating_results/by_month', params: { month: '2025-06' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].first['date']).to eq('2025-06-02')
      expect(json['data'].last['date']).to eq('2025-06-01')
      expect(json['data'].first['notes']).to eq('Segundo día')
    end
  end

  describe 'GET /api/admin/daily_operating_results/preview' do
    it 'returns 422 when date is invalid' do
      get '/api/admin/daily_operating_results/preview', params: { date: 'bad', percent: 0.1 }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns preview data for eligible investors' do
      target_date = Date.new(2025, 6, 3)
      at_time = Time.zone.local(target_date.year, target_date.month, target_date.day, 17, 0, 0)
      create_investor_with_balance(balance: 1000, at_time: at_time)

      get '/api/admin/daily_operating_results/preview', params: { date: '2025-06-03', percent: 1.0 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['date']).to eq('2025-06-03')
      expect(json['data']['investors_count']).to eq(1)
      expect(json['data']['investors'].first).to have_key('delta')
    end
  end

  describe 'POST /api/admin/daily_operating_results' do
    it 'creates a new daily operating result and portfolio histories' do
      target_date = Date.new(2025, 6, 4)
      at_time = Time.zone.local(target_date.year, target_date.month, target_date.day, 17, 0, 0)
      inv = create_investor_with_balance(balance: 1000, at_time: at_time)

      post '/api/admin/daily_operating_results', params: { date: '2025-06-04', percent: 1.0 }

      expect(response).to have_http_status(:created)
      expect(DailyOperatingResult.find_by(date: target_date)).to be_present
      expect(PortfolioHistory.where(investor_id: inv.id, event: 'OPERATING_RESULT').count).to eq(1)
    end

    it 'returns 409 on duplicate date' do
      target_date = Date.new(2025, 6, 5)
      DailyOperatingResult.create!(date: target_date, percent: 0.1, applied_by: admin, applied_at: Time.current)

      post '/api/admin/daily_operating_results', params: { date: '2025-06-05', percent: 1.0 }
      expect(response).to have_http_status(:conflict)
    end

    it 'allows creating a past date even when a later date exists' do
      DailyOperatingResult.create!(date: Date.new(2025, 6, 10), percent: 0.1, applied_by: admin, applied_at: Time.current)
      target_date = Date.new(2025, 6, 9)
      at_time = Time.zone.local(target_date.year, target_date.month, target_date.day, 17, 0, 0)
      create_investor_with_balance(balance: 1000, at_time: at_time)

      post '/api/admin/daily_operating_results', params: { date: '2025-06-09', percent: 1.0 }
      expect(response).to have_http_status(:created)
    end

    it 'returns 422 when no active investors have capital at that date' do
      post '/api/admin/daily_operating_results', params: { date: '2025-06-11', percent: 1.0 }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['error']).to include('No hay inversores activos con capital')
      expect(DailyOperatingResult.find_by(date: Date.new(2025, 6, 11))).to be_nil
    end
  end
end
