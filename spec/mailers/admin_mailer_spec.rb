# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminMailer, type: :mailer do
  # Create admin users for notifications
  let!(:admin_user) do
    User.create!(
      email: 'admin@example.com',
      name: 'Admin',
      role: 'ADMIN',
      notify_deposit_created: true,
      notify_withdrawal_created: true
    )
  end

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
      method: 'CRYPTO',
      network: 'TRC20',
      wallet_address: 'TQ2abc123...',
      status: 'PENDING',
      requested_at: Time.current
    )
  end

  describe '#new_deposit_notification' do
    let(:mail) { described_class.new_deposit_notification(deposit_request) }

    it 'renders the headers' do
      expect(mail.subject).to match('Nueva solicitud DEPÓSITO')
      expect(mail.subject).to match('John Doe')
      expect(mail.to).to include('admin@example.com')
      expect(mail.to).to include('winbit.cfds@gmail.com')
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('John Doe')
      expect(mail.body.encoded).to match('john@example.com')
      expect(mail.body.encoded).to match('USDT')
      expect(mail.body.encoded).to match('TRC20')
    end

    it 'includes attachment link when present' do
      expect(mail.body.encoded).to match('Ver comprobante')
    end

    it 'always includes operations inbox even if admin toggles are off' do
      admin_user.update!(notify_deposit_created: false)
      User.where.not(id: admin_user.id).update_all(notify_deposit_created: false)
      mail = described_class.new_deposit_notification(deposit_request)
      expect(mail.to).to include('winbit.cfds@gmail.com')
      expect(mail.to).not_to include(admin_user.email)
    end

    it 'sends only to operations inbox while Resend is in testing mode' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('RESEND_FROM_EMAIL', '').and_return('Winbit <onboarding@resend.dev>')

      mail = described_class.new_deposit_notification(deposit_request)
      expect(mail.to).to eq(['winbit.cfds@gmail.com'])
    end
  end

  describe '#new_withdrawal_notification' do
    before { portfolio } # Ensure portfolio exists

    let(:mail) { described_class.new_withdrawal_notification(withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to match('Nueva solicitud RETIRO')
      expect(mail.subject).to match('John Doe')
      expect(mail.to).to include('admin@example.com')
      expect(mail.to).to include('winbit.cfds@gmail.com')
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('John Doe')
      expect(mail.body.encoded).to match('john@example.com')
      expect(mail.body.encoded).to match('Crypto')
      expect(mail.body.encoded).to match('TRC20')
      expect(mail.body.encoded).to match('TQ2abc123...')
    end

    context 'when withdrawal is total' do
      let(:withdrawal_request) do
        InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          amount: 9900,
          method: 'LEMON_CASH',
          lemontag: '$totaluser',
          status: 'PENDING',
          requested_at: Time.current
        )
      end

      it 'indicates it is a total withdrawal' do
        expect(mail.body.encoded).to match('Retiro total')
      end
    end
  end

  describe '#withdrawal_approved_notification' do
    let(:approved_withdrawal) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'WITHDRAWAL',
        amount: 15000,
        method: 'USDT',
        status: 'APPROVED',
        requested_at: Time.current,
        processed_at: Time.current
      )
    end
    let(:mail) { described_class.withdrawal_approved_notification(approved_withdrawal, { fee_amount: 45.75 }) }

    it 'renders the headers' do
      expect(mail.subject).to match('Retiro aprobado de John Doe')
      expect(mail.to).to include('admin@example.com')
    end

    it 'renders the body with withdrawal fee details' do
      expect(mail.body.encoded).to match('Comisión por retiro')
      expect(mail.body.encoded).to match('Total deducido de la cuenta')
      expect(mail.body.encoded).to match('ID solicitud')
    end
  end
end
