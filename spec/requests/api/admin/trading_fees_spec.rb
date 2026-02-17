require 'rails_helper'

RSpec.describe 'Admin Trading Fees API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  before do
    login_as(admin, scope: :user)
  end

  after do
    logout(:user)
  end

  def create_investor_with_portfolio(email:)
    inv = Investor.create!(email: email, name: email.split('@').first, status: 'ACTIVE')
    Portfolio.create!(investor: inv, current_balance: 0, total_invested: 0)
    inv
  end

  def add_history(inv:, event:, amount:, date:, prev:, newb:, status: 'COMPLETED')
    PortfolioHistory.create!(
      investor: inv,
      event: event,
      amount: amount,
      previous_balance: prev,
      new_balance: newb,
      status: status,
      date: date,
    )
  end

  describe 'GET /api/admin/trading_fees' do
    it 'lists applied trading fees' do
      inv = create_investor_with_portfolio(email: 'inv1@test.com')

      fee = TradingFee.create!(
        investor: inv,
        applied_by: admin,
        period_start: Date.new(2025, 10, 1),
        period_end: Date.new(2025, 12, 31),
        profit_amount: 100,
        fee_percentage: 30,
        fee_amount: 30,
        applied_at: Time.current,
      )

      get '/api/admin/trading_fees'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first['id']).to eq(fee.id)
      expect(json.first['investor_id']).to eq(inv.id)
    end
  end

  describe 'GET /api/admin/trading_fees/calculate' do
    it 'returns 422 when there are no profits in the requested period' do
      inv = create_investor_with_portfolio(email: 'inv2@test.com')

      get '/api/admin/trading_fees/calculate', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 30,
      }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['error']).to include('No hay ganancias')
      expect(json['profit_amount']).to eq(0)
    end

    it 'returns a preview when there are profits and no existing fee' do
      inv = create_investor_with_portfolio(email: 'inv3@test.com')
      inv.portfolio.update!(current_balance: 1100, total_invested: 1000)

      add_history(inv: inv, event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2025, 10, 1, 19, 0, 0), prev: 0, newb: 1000)
      add_history(inv: inv, event: 'OPERATING_RESULT', amount: 100, date: Time.zone.local(2025, 11, 10, 17, 0, 0), prev: 1000, newb: 1100)

      get '/api/admin/trading_fees/calculate', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 30,
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['profit_amount']).to eq(100.0)
      expect(json['fee_amount'].to_f).to eq(30.0)
      expect(json['already_applied']).to eq(false)
    end

    it 'returns 409 when fee already exists for that period' do
      inv = create_investor_with_portfolio(email: 'inv4@test.com')

      TradingFee.create!(
        investor: inv,
        applied_by: admin,
        period_start: Date.new(2025, 10, 1),
        period_end: Date.new(2025, 12, 31),
        profit_amount: 100,
        fee_percentage: 30,
        fee_amount: 30,
        applied_at: Time.current,
      )

      get '/api/admin/trading_fees/calculate', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 30,
      }

      expect(response).to have_http_status(:conflict)
      json = JSON.parse(response.body)
      expect(json['already_applied']).to eq(true)
      expect(json['error']).to include('ya aplicado')
    end

    it 'returns 422 when investor is ANNUAL but period is not a full calendar year' do
      inv = create_investor_with_portfolio(email: 'inv_annual@test.com')
      inv.update!(trading_fee_frequency: 'ANNUAL')

      get '/api/admin/trading_fees/calculate', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 30,
      }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['error']).to include('ANNUAL')
    end

    it 'returns 422 when investor is MONTHLY but period is not a full month' do
      inv = create_investor_with_portfolio(email: 'inv_monthly@test.com')
      inv.update!(trading_fee_frequency: 'MONTHLY')

      get '/api/admin/trading_fees/calculate', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 30,
      }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['error']).to include('MONTHLY')
    end
  end

  describe 'POST /api/admin/trading_fees' do
    it 'applies a trading fee for an explicit period' do
      inv = create_investor_with_portfolio(email: 'inv5@test.com')
      inv.portfolio.update!(current_balance: 1100, total_invested: 1000)

      add_history(inv: inv, event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2025, 10, 1, 19, 0, 0), prev: 0, newb: 1000)
      add_history(inv: inv, event: 'OPERATING_RESULT', amount: 100, date: Time.zone.local(2025, 11, 10, 17, 0, 0), prev: 1000, newb: 1100)

      post '/api/admin/trading_fees', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 30,
        notes: 'test',
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['investor_id']).to eq(inv.id)
      expect(json['fee_amount'].to_f).to eq(30.0)

      inv.reload
      expect(inv.portfolio.current_balance.to_f).to eq(1070.0)
      expect(TradingFee.where(investor_id: inv.id).count).to eq(1)
      expect(PortfolioHistory.where(investor_id: inv.id, event: 'TRADING_FEE').count).to eq(1)
    end

    it 'returns 422 for invalid percentage' do
      inv = create_investor_with_portfolio(email: 'inv6@test.com')

      post '/api/admin/trading_fees', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 0,
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /api/admin/trading_fees/:id' do
    it 'updates an applied trading fee by creating an adjustment and updating balance' do
      inv = create_investor_with_portfolio(email: 'edit1@test.com')
      inv.portfolio.update!(current_balance: 1100, total_invested: 1000)

      add_history(inv: inv, event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2025, 10, 1, 19, 0, 0), prev: 0, newb: 1000)
      add_history(inv: inv, event: 'OPERATING_RESULT', amount: 100, date: Time.zone.local(2025, 11, 10, 17, 0, 0), prev: 1000, newb: 1100)

      # Apply original fee: 30% => 30
      post '/api/admin/trading_fees', params: {
        investor_id: inv.id,
        period_start: '2025-10-01',
        period_end: '2025-12-31',
        fee_percentage: 30,
        notes: 'original',
      }
      expect(response).to have_http_status(:created)
      fee_id = JSON.parse(response.body)['id']

      inv.reload
      expect(inv.portfolio.current_balance.to_f).to eq(1070.0)

      # Edit fee: 20% => 20, refund 10
      login_as(admin, scope: :user)
      patch "/api/admin/trading_fees/#{fee_id}", params: { fee_percentage: 20, notes: 'edited' }
      expect(response).to have_http_status(:ok)

      inv.reload
      expect(inv.portfolio.current_balance.to_f).to eq(1080.0)

      fee = TradingFee.find(fee_id)
      expect(fee.fee_percentage.to_f).to eq(20.0)
      expect(fee.fee_amount.to_f).to eq(20.0)
      expect(fee.notes).to eq('edited')

      adj = PortfolioHistory.where(investor_id: inv.id, event: 'TRADING_FEE_ADJUSTMENT').order(date: :desc).first
      expect(adj).to be_present
      expect(adj.amount.to_f).to eq(10.0) # refund
    end
  end

  describe 'GET /api/admin/trading_fees/investors_summary' do
    it 'returns active investors with invested > 0 and monthly breakdown' do
      inv1 = create_investor_with_portfolio(email: 'sum1@test.com')
      inv2 = create_investor_with_portfolio(email: 'sum2@test.com')

      # inv1 invested + profits
      add_history(inv: inv1, event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2025, 10, 2, 19, 0, 0), prev: 0, newb: 1000)
      add_history(inv: inv1, event: 'OPERATING_RESULT', amount: 10, date: Time.zone.local(2025, 10, 10, 17, 0, 0), prev: 1000, newb: 1010)
      add_history(inv: inv1, event: 'OPERATING_RESULT', amount: 5, date: Time.zone.local(2025, 11, 10, 17, 0, 0), prev: 1010, newb: 1015)

      # inv2 no invested (withdrawal cancels)
      add_history(inv: inv2, event: 'DEPOSIT', amount: 1000, date: Time.zone.local(2025, 10, 2, 19, 0, 0), prev: 0, newb: 1000)
      add_history(inv: inv2, event: 'WITHDRAWAL', amount: 1000, date: Time.zone.local(2025, 10, 3, 19, 0, 0), prev: 1000, newb: 0)

      get '/api/admin/trading_fees/investors_summary', params: {
        period_start: '2025-10-01',
        period_end: '2025-12-31',
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['investor_id'] }).to contain_exactly(inv1.id)

      row = json.first
      expect(row['profit_amount']).to eq(15.0)
      expect(row['has_profit']).to eq(true)
      expect(row['monthly_profits']).to be_an(Array)
      months = row['monthly_profits'].map { |m| m['month'] }
      expect(months).to include('2025-10', '2025-11', '2025-12')
    end
  end
end
