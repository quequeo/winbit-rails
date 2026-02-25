require 'rails_helper'

RSpec.describe Requests::Approve, type: :service do
  def t(y, m, d, hh, mm = 0, ss = 0)
    Time.zone.local(y, m, d, hh, mm, ss)
  end

  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 5000, total_invested: 5000) }
  let!(:admin) { User.create!(email: 'admin-approve@test.com', name: 'Admin', role: 'ADMIN') }

  describe '#call' do
    context 'with a valid pending deposit request' do
      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'DEPOSIT',
          method: 'USDT',
          amount: 1000,
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      it 'updates request status to APPROVED' do
        service = described_class.new(request_id: request.id, approved_by: admin)
        service.call

        request.reload
        expect(request.status).to eq('APPROVED')
        expect(request.processed_at).to be_present
      end

      it 'updates portfolio balance' do
        service = described_class.new(request_id: request.id, approved_by: admin)
        service.call

        portfolio.reload
        expect(portfolio.current_balance).to eq(6000.0)
        expect(portfolio.total_invested).to eq(6000.0)
      end

      it 'creates a portfolio history record' do
        expect {
          service = described_class.new(request_id: request.id, approved_by: admin)
          service.call
        }.to change(PortfolioHistory, :count).by(1)

        history = PortfolioHistory.last
        expect(history.investor_id).to eq(investor.id)
        expect(history.amount).to eq(1000.0)
        expect(history.event).to eq('DEPOSIT')
        expect(history.previous_balance).to eq(5000.0)
        expect(history.new_balance).to eq(6000.0)
      end
    end

    context 'with a valid pending withdrawal request' do
      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 1000,
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      it 'updates request status to APPROVED' do
        service = described_class.new(request_id: request.id, approved_by: admin)
        service.call

        request.reload
        expect(request.status).to eq('APPROVED')
        expect(request.processed_at).to be_present
      end

      it 'decreases portfolio balance' do
        service = described_class.new(request_id: request.id, approved_by: admin)
        service.call

        portfolio.reload
        expect(portfolio.current_balance).to eq(4000.0)
      end

      it 'creates a portfolio history record' do
        expect {
          service = described_class.new(request_id: request.id, approved_by: admin)
          service.call
        }.to change(PortfolioHistory, :count).by(1)

        history = PortfolioHistory.last
        expect(history.investor_id).to eq(investor.id)
        expect(history.amount).to eq(1000.0)
        expect(history.event).to eq('WITHDRAWAL')
        expect(history.previous_balance).to eq(5000.0)
        expect(history.new_balance).to eq(4000.0)
      end
    end

    context 'with invalid request' do
      it 'raises error when request not found' do
        service = described_class.new(request_id: 'nonexistent')

        expect {
          service.call
        }.to raise_error(StandardError, /Solicitud no encontrada/)
      end

      it 'raises error when request is not pending' do
        approved_request = InvestorRequest.create!(
          investor: investor,
          request_type: 'DEPOSIT',
          method: 'USDT',
          amount: 1000,
          status: 'APPROVED',
          requested_at: Time.current,
          processed_at: Time.current
        )

        service = described_class.new(request_id: approved_request.id, approved_by: admin)

        expect {
          service.call
        }.to raise_error(StandardError, /Solo se pueden aprobar solicitudes pendientes/)
      end
    end

    context 'when backfilling (there are future histories after processed_at)' do
      let!(:future_history) do
        PortfolioHistory.create!(
          investor: investor,
          event: 'OPERATING_RESULT',
          amount: 100,
          previous_balance: 5000,
          new_balance: 5100,
          status: 'COMPLETED',
          date: t(2026, 2, 1, 17, 0, 0)
        )
      end

      it 'uses history replay to keep balances consistent' do
        req = InvestorRequest.create!(
          investor: investor,
          request_type: 'DEPOSIT',
          method: 'USDT',
          amount: 1000,
          status: 'PENDING',
          requested_at: Time.current
        )

        service = described_class.new(request_id: req.id, processed_at: t(2026, 1, 15, 19, 0, 0), approved_by: admin)
        service.call

        expect(PortfolioHistory.where(investor_id: investor.id).count).to be >= 2
        expect(investor.reload.portfolio.current_balance.to_f).to be > 0.0
      end
    end

    context 'with insufficient balance for withdrawal' do
      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 10000, # More than available balance
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      it 'raises error' do
        service = described_class.new(request_id: request.id, approved_by: admin)

        expect {
          service.call
        }.to raise_error(StandardError, /Balance insuficiente para realizar el retiro/)
      end
    end

    context 'with withdrawal and pending profits' do
      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 1000,
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      before do
        portfolio.update!(current_balance: 5500, total_invested: 5000)
        PortfolioHistory.create!(
          investor: investor,
          event: 'OPERATING_RESULT',
          amount: 500,
          previous_balance: 5000,
          new_balance: 5500,
          status: 'COMPLETED',
          date: 1.day.ago
        )
      end

      it 'applies withdrawal trading fee and stores metadata' do
        service = described_class.new(request_id: request.id, approved_by: admin)

        expect { service.call }.to change(TradingFee, :count).by(1)

        request.reload
        expect(request.status).to eq('APPROVED')

        fee = TradingFee.last
        expect(fee.source).to eq('WITHDRAWAL')
        expect(fee.withdrawal_request_id).to eq(request.id)
        expect(fee.withdrawal_amount.to_f).to eq(1000.0)

        withdrawal_history = PortfolioHistory.where(investor: investor, event: 'WITHDRAWAL').order(date: :desc).first
        fee_history = PortfolioHistory.where(investor: investor, event: 'TRADING_FEE').order(date: :desc).first

        expect(withdrawal_history).to be_present
        expect(fee_history).to be_present
        # Investor receives full requested amount; fee is charged additionally
        expect(withdrawal_history.amount.to_f).to eq(1000.0)
        expect(fee_history.amount.to_f).to be < 0
        # Total deducted from portfolio = withdrawal + fee
        expect(withdrawal_history.amount.to_f + fee_history.amount.to_f.abs).to be > 1000.0
      end
    end

    context 'with withdrawal and zero pending profit (break-even)' do
      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 1000,
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      before do
        portfolio.update!(current_balance: 5000, total_invested: 5000)
      end

      it 'approves without charging any trading fee' do
        service = described_class.new(request_id: request.id, approved_by: admin)

        expect { service.call }.not_to change(TradingFee, :count)

        request.reload
        expect(request.status).to eq('APPROVED')

        withdrawal_history = PortfolioHistory.where(investor: investor, event: 'WITHDRAWAL').order(date: :desc).first
        fee_history = PortfolioHistory.where(investor: investor, event: 'TRADING_FEE').order(date: :desc).first

        expect(withdrawal_history).to be_present
        expect(withdrawal_history.amount.to_f).to eq(1000.0)
        expect(fee_history).to be_nil
      end
    end

    context 'with withdrawal and negative pending profit (loss)' do
      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 1000,
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      before do
        portfolio.update!(current_balance: 4500, total_invested: 5000)
        PortfolioHistory.create!(
          investor: investor,
          event: 'OPERATING_RESULT',
          amount: -500,
          previous_balance: 5000,
          new_balance: 4500,
          status: 'COMPLETED',
          date: 1.day.ago
        )
      end

      it 'approves without charging any trading fee' do
        service = described_class.new(request_id: request.id, approved_by: admin)

        expect { service.call }.not_to change(TradingFee, :count)

        request.reload
        expect(request.status).to eq('APPROVED')

        withdrawal_history = PortfolioHistory.where(investor: investor, event: 'WITHDRAWAL').order(date: :desc).first
        fee_history = PortfolioHistory.where(investor: investor, event: 'TRADING_FEE').order(date: :desc).first

        expect(withdrawal_history).to be_present
        expect(withdrawal_history.amount.to_f).to eq(1000.0)
        expect(fee_history).to be_nil
      end
    end
  end
end
