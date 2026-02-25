require 'rails_helper'

RSpec.describe 'Public investors', type: :request do
  it 'GET /api/public/investor/:email returns investor + portfolio' do
    investor = Investor.create!(email: 'test@example.com', name: 'juan perez', status: 'ACTIVE')
    Portfolio.create!(
      investor_id: investor.id,
      current_balance: 100,
      total_invested: 80,
      accumulated_return_usd: 20,
      accumulated_return_percent: 25,
      annual_return_usd: 10,
      annual_return_percent: 12.5
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}"

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'investor', 'email')).to eq('test@example.com')
    expect(json.dig('data', 'investor', 'name')).to eq('Juan Perez')
    expect(json.dig('data', 'portfolio', 'currentBalance')).to eq(100.0)

     # Strategy return (TWR) fields are present
     expect(json.dig('data', 'portfolio', 'strategyReturnYtdUSD')).to be_a(Numeric)
     expect(json.dig('data', 'portfolio', 'strategyReturnYtdPercent')).to be_a(Numeric)
     expect(json.dig('data', 'portfolio', 'strategyReturnAllUSD')).to be_a(Numeric)
     expect(json.dig('data', 'portfolio', 'strategyReturnAllPercent')).to be_a(Numeric)
  end

  it 'GET /api/public/investor/:email returns 404 when missing' do
    get "/api/public/investor/#{CGI.escape('missing@example.com')}"
    expect(response).to have_http_status(:not_found)
  end

  it 'GET /api/public/investor/:email returns 403 when inactive' do
    Investor.create!(email: 'inactive@example.com', name: 'x', status: 'INACTIVE')

    get "/api/public/investor/#{CGI.escape('inactive@example.com')}"
    expect(response).to have_http_status(:forbidden)
  end

  it 'GET /api/public/investor/:email/history returns history desc' do
    investor = Investor.create!(email: 'h@example.com', name: 'h', status: 'ACTIVE')

    PortfolioHistory.create!(
      investor_id: investor.id,
      date: Time.utc(2024, 2, 1),
      event: 'DEPOSIT',
      amount: 100,
      previous_balance: 0,
      new_balance: 100,
      status: 'COMPLETED'
    )
    PortfolioHistory.create!(
      investor_id: investor.id,
      date: Time.utc(2024, 3, 1),
      event: 'WITHDRAWAL',
      amount: 10,
      previous_balance: 100,
      new_balance: 90,
      status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data'].length).to eq(2)
    expect(json['data'][0]['event']).to eq('WITHDRAWAL')
    expect(json['data'][1]['event']).to eq('DEPOSIT')
  end

  it 'GET /api/public/investor/:email/history includes tradingFeePercentage for TRADING_FEE' do
    investor = Investor.create!(email: 'fee@example.com', name: 'fee', status: 'ACTIVE')
    admin = User.create!(email: 'admin@example.com', name: 'Admin', role: 'ADMIN')

    # Create a TradingFee and a matching PortfolioHistory (within 10 minutes) so controller can attach metadata
    tf = TradingFee.create!(
      investor: investor,
      applied_by: admin,
      period_start: Date.new(2025, 10, 1),
      period_end: Date.new(2025, 12, 31),
      profit_amount: 1000,
      fee_percentage: 30,
      fee_amount: 300,
      applied_at: Time.utc(2026, 1, 22, 17, 0, 0)
    )

    PortfolioHistory.create!(
      investor_id: investor.id,
      date: tf.applied_at,
      event: 'TRADING_FEE',
      amount: -tf.fee_amount.to_f,
      previous_balance: 1000,
      new_balance: 700,
      status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    fee_item = json['data'].find { |it| it['event'] == 'TRADING_FEE' }
    expect(fee_item).to be_present
    expect(fee_item['tradingFeePeriodLabel']).to eq('Q4 2025')
    expect(fee_item['tradingFeePercentage']).to eq(30.0)
  end

  it 'GET /api/public/investor/:email/history includes withdrawal metadata for withdrawal trading fee' do
    investor = Investor.create!(email: 'withdraw-fee@example.com', name: 'wf', status: 'ACTIVE')
    admin = User.create!(email: 'admin2@example.com', name: 'Admin 2', role: 'ADMIN')
    req = InvestorRequest.create!(
      investor: investor,
      request_type: 'WITHDRAWAL',
      amount: 15000,
      method: 'USDT',
      status: 'APPROVED',
      requested_at: Time.current,
      processed_at: Time.current
    )

    tf = TradingFee.create!(
      investor: investor,
      applied_by: admin,
      period_start: Date.current,
      period_end: Date.current + 1.day,
      profit_amount: 100,
      fee_percentage: 30,
      fee_amount: 30,
      source: 'WITHDRAWAL',
      withdrawal_amount: 15000,
      withdrawal_request_id: req.id,
      applied_at: Time.current
    )

    PortfolioHistory.create!(
      investor_id: investor.id,
      date: tf.applied_at,
      event: 'TRADING_FEE',
      amount: -30,
      previous_balance: 1000,
      new_balance: 970,
      status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    fee_item = JSON.parse(response.body)['data'].find { |it| it['event'] == 'TRADING_FEE' }
    expect(fee_item).to be_present
    expect(fee_item['tradingFeeSource']).to eq('WITHDRAWAL')
    expect(fee_item['tradingFeePeriodLabel']).to eq('Retiro')
    expect(fee_item['tradingFeeWithdrawalAmount']).to eq(15000.0)
  end

  it 'GET /api/public/investor/:email/history returns YYYY-MM for single-month periodic fee' do
    investor = Investor.create!(email: 'monthly-fee@example.com', name: 'Monthly', status: 'ACTIVE')
    admin = User.create!(email: 'admin-monthly@example.com', name: 'Admin', role: 'ADMIN')

    tf = TradingFee.create!(
      investor: investor,
      applied_by: admin,
      period_start: Date.new(2026, 1, 1),
      period_end: Date.new(2026, 1, 31),
      profit_amount: 500,
      fee_percentage: 25,
      fee_amount: 125,
      source: 'PERIODIC',
      applied_at: Time.utc(2026, 1, 31, 18, 30, 0)
    )

    PortfolioHistory.create!(
      investor_id: investor.id,
      date: tf.applied_at,
      event: 'TRADING_FEE',
      amount: -tf.fee_amount.to_f,
      previous_balance: 1000,
      new_balance: 875,
      status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    fee_item = JSON.parse(response.body)['data'].find { |it| it['event'] == 'TRADING_FEE' }
    expect(fee_item).to be_present
    expect(fee_item['tradingFeePeriodLabel']).to eq('2026-01')
  end

  it 'GET /api/public/investor/:email/history orders withdrawal before its trading fee when same date' do
    investor = Investor.create!(email: 'order-fee@example.com', name: 'Order', status: 'ACTIVE')
    admin = User.create!(email: 'admin-order@example.com', name: 'Admin', role: 'ADMIN')
    t = Time.utc(2026, 2, 25, 19, 54, 43)

    req = InvestorRequest.create!(
      investor: investor, request_type: 'WITHDRAWAL', amount: 2000,
      method: 'USDT', status: 'APPROVED', requested_at: t, processed_at: t
    )
    tf = TradingFee.create!(
      investor: investor, applied_by: admin,
      period_start: t.to_date, period_end: t.to_date + 1.day,
      profit_amount: 22.34, fee_percentage: 25, fee_amount: 5.59,
      source: 'WITHDRAWAL', withdrawal_amount: 2000,
      withdrawal_request_id: req.id, applied_at: t
    )

    PortfolioHistory.create!(
      investor_id: investor.id, date: t, event: 'WITHDRAWAL',
      amount: 2000, previous_balance: 35_552, new_balance: 33_552, status: 'COMPLETED'
    )
    PortfolioHistory.create!(
      investor_id: investor.id, date: t, event: 'TRADING_FEE',
      amount: -5.59, previous_balance: 33_552, new_balance: 33_546.41, status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)['data']
    withdrawal_idx = data.index { |it| it['event'] == 'WITHDRAWAL' && it['amount'] == 2000 }
    fee_idx = data.index { |it| it['event'] == 'TRADING_FEE' && it['amount'] == -5.59 }
    expect(withdrawal_idx).to be < fee_idx
  end

  it 'GET /api/public/investor/:email/history matches each TRADING_FEE PH to correct fee by amount when multiple fees exist' do
    investor = Investor.create!(email: 'multi-fee@example.com', name: 'Multi', status: 'ACTIVE')
    admin = User.create!(email: 'admin3@example.com', name: 'Admin 3', role: 'ADMIN')
    base_time = Time.utc(2026, 2, 25, 14, 0, 0)

    req_500 = InvestorRequest.create!(
      investor: investor, request_type: 'WITHDRAWAL', amount: 500,
      method: 'USDT', status: 'APPROVED',
      requested_at: base_time, processed_at: base_time
    )
    req_2000 = InvestorRequest.create!(
      investor: investor, request_type: 'WITHDRAWAL', amount: 2000,
      method: 'USDT', status: 'APPROVED',
      requested_at: base_time + 2.minutes, processed_at: base_time + 2.minutes
    )

    tf_500 = TradingFee.create!(
      investor: investor, applied_by: admin,
      period_start: base_time.to_date, period_end: base_time.to_date + 1.day,
      profit_amount: 22.4, fee_percentage: 25, fee_amount: 5.6,
      source: 'WITHDRAWAL', withdrawal_amount: 500,
      withdrawal_request_id: req_500.id, applied_at: base_time
    )
    tf_2000 = TradingFee.create!(
      investor: investor, applied_by: admin,
      period_start: (base_time + 2.minutes).to_date, period_end: (base_time + 2.minutes).to_date + 1.day,
      profit_amount: 89.6, fee_percentage: 25, fee_amount: 22.4,
      source: 'WITHDRAWAL', withdrawal_amount: 2000,
      withdrawal_request_id: req_2000.id, applied_at: base_time + 2.minutes
    )

    PortfolioHistory.create!(
      investor_id: investor.id, date: tf_2000.applied_at,
      event: 'TRADING_FEE', amount: -22.4,
      previous_balance: 5000, new_balance: 4977.6, status: 'COMPLETED'
    )
    PortfolioHistory.create!(
      investor_id: investor.id, date: tf_500.applied_at,
      event: 'TRADING_FEE', amount: -5.6,
      previous_balance: 5500, new_balance: 5494.4, status: 'COMPLETED'
    )

    get "/api/public/investor/#{CGI.escape(investor.email)}/history"

    expect(response).to have_http_status(:ok)
    fee_items = JSON.parse(response.body)['data'].select { |it| it['event'] == 'TRADING_FEE' }
    expect(fee_items.size).to eq(2)

    by_amount = fee_items.index_by { |it| it['amount'] }
    expect(by_amount[-22.4]['tradingFeeWithdrawalAmount']).to eq(2000.0)
    expect(by_amount[-5.6]['tradingFeeWithdrawalAmount']).to eq(500.0)
  end

  describe 'GET /api/public/investor/:email/withdrawal_fee_preview' do
    let!(:admin) { User.create!(email: 'adm@example.com', name: 'Admin', role: 'ADMIN') }

    def build_investor(email:, balance:, fee_pct: 30)
      inv = Investor.create!(
        email: email, name: 'Test', status: 'ACTIVE',
        trading_fee_percentage: fee_pct
      )
      Portfolio.create!(
        investor_id: inv.id, current_balance: balance, total_invested: balance,
        accumulated_return_usd: 0, accumulated_return_percent: 0,
        annual_return_usd: 0, annual_return_percent: 0
      )
      inv
    end

    it 'returns zero fee when no pending profit exists' do
      investor = build_investor(email: 'noprofit@example.com', balance: 10_000)

      get "/api/public/investor/#{CGI.escape(investor.email)}/withdrawal_fee_preview?amount=5000"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)['data']
      expect(json['withdrawalAmount']).to eq(5000.0)
      expect(json['feeAmount']).to eq(0.0)
      expect(json['hasFee']).to be(false)
    end

    it 'calculates fee proportional to pending profit and withdrawal amount' do
      investor = build_investor(email: 'profit@example.com', balance: 10_000)

      PortfolioHistory.create!(
        investor_id: investor.id, event: 'OPERATING_RESULT', status: 'COMPLETED',
        amount: 2000, previous_balance: 8000, new_balance: 10_000,
        date: 1.day.ago
      )

      get "/api/public/investor/#{CGI.escape(investor.email)}/withdrawal_fee_preview?amount=5000"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)['data']
      # realized_profit = 2000 * (5000 / 10_000) = 1000
      # fee = 1000 * (30 / 100) = 300
      expect(json['withdrawalAmount']).to eq(5000.0)
      expect(json['feeAmount']).to eq(300.0)
      expect(json['feePercentage']).to eq(30.0)
      expect(json['realizedProfit']).to eq(1000.0)
      expect(json['hasFee']).to be(true)
    end

    it 'deducts already-paid trading fees from pending profit' do
      investor = build_investor(email: 'alreadypaid@example.com', balance: 10_000)

      PortfolioHistory.create!(
        investor_id: investor.id, event: 'OPERATING_RESULT', status: 'COMPLETED',
        amount: 2000, previous_balance: 8000, new_balance: 10_000,
        date: 2.days.ago
      )

      req = InvestorRequest.create!(
        investor: investor, request_type: 'WITHDRAWAL', amount: 1000,
        method: 'CASH_ARS', status: 'APPROVED',
        requested_at: 2.days.ago, processed_at: 2.days.ago
      )

      TradingFee.create!(
        investor: investor, applied_by: admin,
        period_start: 2.days.ago.to_date, period_end: 1.day.ago.to_date,
        profit_amount: 1000, fee_percentage: 30, fee_amount: 300,
        source: 'WITHDRAWAL', withdrawal_amount: 1000,
        withdrawal_request_id: req.id, applied_at: 2.days.ago
      )

      get "/api/public/investor/#{CGI.escape(investor.email)}/withdrawal_fee_preview?amount=5000"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)['data']
      # pending_profit = 2000 - 1000 (already paid) = 1000
      # realized_profit = 1000 * (5000 / 10_000) = 500
      # fee = 500 * 0.30 = 150
      expect(json['feeAmount']).to eq(150.0)
      expect(json['realizedProfit']).to eq(500.0)
    end

    it 'returns 422 when amount is zero' do
      investor = build_investor(email: 'zero@example.com', balance: 10_000)
      get "/api/public/investor/#{CGI.escape(investor.email)}/withdrawal_fee_preview?amount=0"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when amount exceeds balance' do
      investor = build_investor(email: 'exceed@example.com', balance: 1_000)
      get "/api/public/investor/#{CGI.escape(investor.email)}/withdrawal_fee_preview?amount=99999"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for unknown investor' do
      get "/api/public/investor/#{CGI.escape('nobody@example.com')}/withdrawal_fee_preview?amount=100"
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 403 for inactive investor' do
      inv = Investor.create!(email: 'inactive2@example.com', name: 'x', status: 'INACTIVE')
      get "/api/public/investor/#{CGI.escape(inv.email)}/withdrawal_fee_preview?amount=100"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
