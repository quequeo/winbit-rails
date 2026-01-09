require 'rails_helper'

RSpec.describe Requests::Approve, type: :service do
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Investor', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 5000, total_invested: 5000) }

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
        service = described_class.new(request_id: request.id)
        service.call

        request.reload
        expect(request.status).to eq('APPROVED')
        expect(request.processed_at).to be_present
      end

      it 'updates portfolio balance' do
        service = described_class.new(request_id: request.id)
        service.call

        portfolio.reload
        expect(portfolio.current_balance).to eq(6000.0)
        expect(portfolio.total_invested).to eq(6000.0)
      end

      it 'creates a portfolio history record' do
        expect {
          service = described_class.new(request_id: request.id)
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
        service = described_class.new(request_id: request.id)
        service.call

        request.reload
        expect(request.status).to eq('APPROVED')
        expect(request.processed_at).to be_present
      end

      it 'decreases portfolio balance' do
        service = described_class.new(request_id: request.id)
        service.call

        portfolio.reload
        expect(portfolio.current_balance).to eq(4000.0)
      end

      it 'creates a portfolio history record' do
        expect {
          service = described_class.new(request_id: request.id)
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

        service = described_class.new(request_id: approved_request.id)

        expect {
          service.call
        }.to raise_error(StandardError, /Solo se pueden aprobar solicitudes pendientes/)
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
        service = described_class.new(request_id: request.id)

        expect {
          service.call
        }.to raise_error(StandardError, /Balance insuficiente para realizar el retiro/)
      end
    end
  end
end
