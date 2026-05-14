require 'rails_helper'

RSpec.describe Requests::ResetApprovedRequestToPending, type: :service do
  let(:t) { Time.zone.local(2026, 5, 14, 15, 0, 0) }

  describe 'deposit' do
    let!(:investor) { Investor.create!(email: 'reset-dep@test.com', name: 'Inv', status: 'ACTIVE') }
    let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 14_000, total_invested: 14_000) }
    let!(:req) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 14_000,
        status: 'APPROVED',
        requested_at: t - 1.hour,
        processed_at: t
      )
    end

    before do
      PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 14_000,
        previous_balance: 0,
        new_balance: 14_000,
        status: 'COMPLETED',
        date: t
      )
    end

    it 'vuelve la solicitud a PENDING, borra el DEPOSIT y recalcula el portfolio' do
      expect { described_class.new(request_id: req.id).call }
        .to change { PortfolioHistory.where(investor: investor, event: 'DEPOSIT').count }.by(-1)

      req.reload
      portfolio.reload
      expect(req.status).to eq('PENDING')
      expect(req.processed_at).to be_nil
      expect(portfolio.current_balance.to_f).to eq(0.0)
      expect(portfolio.total_invested.to_f).to eq(0.0)
    end

    it 'falla si hay OPERATING_RESULT posterior' do
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: 100,
        previous_balance: 14_000,
        new_balance: 14_100,
        status: 'COMPLETED',
        date: t + 1.hour
      )

      expect do
        described_class.new(request_id: req.id).call
      end.to raise_error(StandardError, /operativa diaria/)

      expect(req.reload.status).to eq('APPROVED')
    end
  end

  describe 'withdrawal with fee' do
    let!(:investor) { Investor.create!(email: 'reset-wd@test.com', name: 'W', status: 'ACTIVE', trading_fee_percentage: 30) }
    let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 4350, total_invested: 5000) }
    let!(:admin) { User.create!(email: 'applier@test.com', name: 'A', role: 'SUPERADMIN') }
    let!(:req) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'WITHDRAWAL',
        method: 'USDT',
        amount: 1000,
        status: 'APPROVED',
        requested_at: t - 1.hour,
        processed_at: t
      )
    end

    before do
      PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 5000,
        previous_balance: 0,
        new_balance: 5000,
        status: 'COMPLETED',
        date: t - 2.days
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: 500,
        previous_balance: 5000,
        new_balance: 5500,
        status: 'COMPLETED',
        date: t - 1.day
      )
    end

    let!(:hist_wd) do
      PortfolioHistory.create!(
        investor: investor,
        event: 'WITHDRAWAL',
        amount: 1000,
        previous_balance: 5500,
        new_balance: 4500,
        status: 'COMPLETED',
        date: t,
        created_at: t
      )
    end

    let!(:hist_fee) do
      PortfolioHistory.create!(
        investor: investor,
        event: 'TRADING_FEE',
        amount: -150,
        previous_balance: 4500,
        new_balance: 4350,
        status: 'COMPLETED',
        date: t,
        created_at: t + 1.second
      )
    end

    let!(:trading_fee) do
      TradingFee.create!(
        investor: investor,
        applied_by: admin,
        period_start: t.to_date,
        period_end: t.to_date + 1.day,
        profit_amount: 500,
        fee_percentage: 30,
        fee_amount: 150,
        source: 'WITHDRAWAL',
        withdrawal_amount: 1000,
        withdrawal_request_id: req.id,
        applied_at: t
      )
    end

    it 'borra retiro, fee en historial, TradingFee y deja PENDING' do
      described_class.new(request_id: req.id).call

      req.reload
      portfolio.reload
      expect(req.status).to eq('PENDING')
      expect(req.processed_at).to be_nil
      expect(TradingFee.find_by(id: trading_fee.id)).to be_nil
      expect(PortfolioHistory.where(investor: investor, event: 'WITHDRAWAL').count).to eq(0)
      expect(PortfolioHistory.where(investor: investor, event: 'TRADING_FEE').count).to eq(0)
      expect(portfolio.current_balance.to_f).to eq(5500.0)
    end
  end
end
