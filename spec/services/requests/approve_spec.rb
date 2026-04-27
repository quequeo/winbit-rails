require 'rails_helper'

RSpec.describe Requests::Approve, type: :service do
  def t(y, m, d, hh, mm = 0, ss = 0)
    Time.zone.local(y, m, d, hh, mm, ss)
  end

  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 5000, total_invested: 5000) }
  let!(:admin) { User.create!(email: 'admin-approve@test.com', name: 'Admin', role: 'ADMIN') }
  # Represents the initial deposit in portfolio history (required for Vpcust profit calculation)
  let!(:initial_deposit_history) do
    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: 5000,
      previous_balance: 0,
      new_balance: 5000,
      status: 'COMPLETED',
      date: 10.days.ago
    )
  end
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

        history = PortfolioHistory.where(event: 'DEPOSIT').order(created_at: :desc).first
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

        history = PortfolioHistory.where(event: 'WITHDRAWAL').last
        expect(history.investor_id).to eq(investor.id)
        expect(history.amount).to eq(1000.0)
        expect(history.event).to eq('WITHDRAWAL')
        expect(history.previous_balance).to eq(5000.0)
        expect(history.new_balance).to eq(4000.0)
      end

      it 'no deja total_invested por debajo de cero si el retiro incluye ganancia' do
        inv = Investor.create!(
          email: 'floor-total-inv@example.com',
          name: 'Floor',
          status: 'ACTIVE',
          trading_fee_percentage: 0
        )
        p = Portfolio.create!(investor: inv, current_balance: 1200, total_invested: 1000)
        t0 = 5.days.ago
        t1 = 3.days.ago
        PortfolioHistory.create!(
          investor: inv,
          event: 'DEPOSIT',
          amount: 1000,
          previous_balance: 0,
          new_balance: 1000,
          status: 'COMPLETED',
          date: t0
        )
        PortfolioHistory.create!(
          investor: inv,
          event: 'OPERATING_RESULT',
          amount: 200,
          previous_balance: 1000,
          new_balance: 1200,
          status: 'COMPLETED',
          date: t1
        )

        big_wd = InvestorRequest.create!(
          investor: inv,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 1100,
          status: 'PENDING',
          requested_at: Time.current
        )

        described_class.new(request_id: big_wd.id, approved_by: admin).call

        p.reload
        expect(p.current_balance.to_f).to eq(100.0)
        expect(p.total_invested.to_f).to eq(1000.0)
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

      it 'applies withdrawal trading fee on full accumulated profit (Vpcust model)' do
        service = described_class.new(request_id: request.id, approved_by: admin)

        expect { service.call }.to change(TradingFee, :count).by(1)

        request.reload
        expect(request.status).to eq('APPROVED')

        fee = TradingFee.last
        expect(fee.source).to eq('WITHDRAWAL')
        expect(fee.withdrawal_request_id).to eq(request.id)
        expect(fee.withdrawal_amount.to_f).to eq(1000.0)

        # profit = current_balance(5500) - vpcust(0, no prior reset) - inflows_since_inception(5000 deposit) = 500
        # fee = 30% of 500 = 150
        expect(fee.profit_amount.to_f).to eq(500.0)
        expect(fee.fee_amount.to_f).to eq(150.0)

        withdrawal_history = PortfolioHistory.where(investor: investor, event: 'WITHDRAWAL').order(date: :desc).first
        fee_history = PortfolioHistory.where(investor: investor, event: 'TRADING_FEE').order(date: :desc).first

        expect(withdrawal_history).to be_present
        expect(fee_history).to be_present
        # Investor receives full requested amount; fee is charged additionally
        expect(withdrawal_history.amount.to_f).to eq(1000.0)
        expect(fee_history.amount.to_f).to be < 0
        # Total deducted = withdrawal(1000) + fee(150) = 1150
        expect(withdrawal_history.amount.to_f + fee_history.amount.to_f.abs).to eq(1150.0)

        portfolio.reload
        expect(portfolio.current_balance.to_f).to eq(4350.0) # 5500 - 1000 - 150
      end

      it 'resets profit base (Vpcust) after fee so next withdrawal has no fee without new profit' do
        service = described_class.new(request_id: request.id, approved_by: admin)
        service.call

        # Second withdrawal — no new operating result
        request2 = InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 100,
          status: 'PENDING',
          requested_at: Time.current
        )

        expect {
          described_class.new(request_id: request2.id, approved_by: admin).call
        }.not_to change(TradingFee, :count)

        portfolio.reload
        expect(portfolio.current_balance.to_f).to eq(4250.0) # 4350 - 100
      end
    end

    context 'with withdrawal after a deposit in the same period (Vpcust model: deposit is an inflow)' do
      # Vpcust = 0 (no prior reset). Deposit 5000 + operating +500 = 5500.
      # Then investor deposits 300 more → balance 5800.
      # Profit = 5800 - 0(vpcust) - 5300(inflows: 5000 deposit + 300 deposit) = 500.
      # Fee = 30% of 500 = 150.
      before do
        portfolio.update!(current_balance: 5800, total_invested: 5300)
        PortfolioHistory.create!(
          investor: investor,
          event: 'OPERATING_RESULT',
          amount: 500,
          previous_balance: 5000,
          new_balance: 5500,
          status: 'COMPLETED',
          date: 2.days.ago
        )
        PortfolioHistory.create!(
          investor: investor,
          event: 'DEPOSIT',
          amount: 300,
          previous_balance: 5500,
          new_balance: 5800,
          status: 'COMPLETED',
          date: 1.day.ago
        )
      end

      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 500,
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      it 'excludes inflows from profit calculation' do
        service = described_class.new(request_id: request.id, approved_by: admin)
        expect { service.call }.to change(TradingFee, :count).by(1)

        fee = TradingFee.last
        expect(fee.profit_amount.to_f).to eq(500.0)
        expect(fee.fee_amount.to_f).to eq(150.0)

        portfolio.reload
        expect(portfolio.current_balance.to_f).to eq(5150.0) # 5800 - 500 - 150
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
