# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminMailer, type: :mailer do
  let(:investor) { Investor.create!(name: 'John Doe', email: 'john@example.com', status: 'ACTIVE') }
  let(:portfolio) { Portfolio.create!(investor: investor, current_balance: 10000, total_invested: 10000) }
  let(:deposit_request) do
    InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      amount: 1000,
      method: 'USDT',
      network: 'TRC20',
      attachment_url: 'https://example.com/image.png',
      status: 'PENDING',
      requested_at: Time.current
    )
  end
  let(:withdrawal_request) do
    InvestorRequest.create!(
      investor: investor,
      request_type: 'WITHDRAWAL',
      amount: 500,
      method: 'LEMON_CASH',
      lemontag: '@john',
      status: 'PENDING',
      requested_at: Time.current
    )
  end

  describe '#new_deposit_notification' do
    let(:mail) { described_class.new_deposit_notification(deposit_request) }

    it 'renders the headers' do
      expect(mail.subject).to match('Nuevo depósito de John Doe')
      expect(mail.to).to include('jaimegarciamendez@gmail.com')
      expect(mail.to).to include('winbit.cfds@gmail.com')
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('John Doe')
      expect(mail.body.encoded).to match('john@example.com')
      expect(mail.body.encoded).to match('USDT')
      expect(mail.body.encoded).to match('TRC20')
    end

    it 'includes attachment link when present' do
      expect(mail.body.encoded).to match('Ver comprobante adjunto')
    end
  end

  describe '#new_withdrawal_notification' do
    before { portfolio } # Ensure portfolio exists

    let(:mail) { described_class.new_withdrawal_notification(withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to match('Nueva solicitud de retiro de John Doe')
      expect(mail.to).to include('jaimegarciamendez@gmail.com')
      expect(mail.to).to include('winbit.cfds@gmail.com')
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('John Doe')
      expect(mail.body.encoded).to match('john@example.com')
      expect(mail.body.encoded).to match('Lemon Cash')
      expect(mail.body.encoded).to match('@john')
    end

    context 'when withdrawal is total' do
      let(:withdrawal_request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          amount: 9900,
          method: 'LEMON_CASH',
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      it 'indicates it is a total withdrawal' do
        expect(mail.body.encoded).to match('RETIRO TOTAL')
      end
    end
  end
end
