require 'rails_helper'

RSpec.describe Requests::Reject, type: :service do
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Investor', status: 'ACTIVE') }

  describe '#call' do
    context 'with a valid pending request' do
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

      it 'updates request status to REJECTED' do
        service = described_class.new(request_id: request.id)
        service.call

        request.reload
        expect(request.status).to eq('REJECTED')
        expect(request.processed_at).to be_present
      end

      it 'sets the processed_at timestamp' do
        service = described_class.new(request_id: request.id)
        
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)
        
        service.call

        request.reload
        expect(request.processed_at).to eq(freeze_time)
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
        }.to raise_error(StandardError, /Solo se pueden rechazar solicitudes pendientes/)
      end
    end

    context 'with withdrawal request' do
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

      it 'successfully rejects the request' do
        service = described_class.new(request_id: request.id)
        service.call

        request.reload
        expect(request.status).to eq('REJECTED')
      end
    end

    context 'with already rejected request' do
      let!(:request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'DEPOSIT',
          method: 'USDT',
          amount: 1000,
          status: 'REJECTED',
          requested_at: Time.current,
          processed_at: Time.current - 1.day
        )
      end

      it 'raises error' do
        service = described_class.new(request_id: request.id)

        expect {
          service.call
        }.to raise_error(StandardError, /Solo se pueden rechazar solicitudes pendientes/)
      end
    end
  end
end
