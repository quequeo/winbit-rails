# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminMailer, type: :mailer do
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
      expect(mail.to).to eq(['contacto@winbit.com.ar'])
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

    it 'does not include other admin emails even if notify toggles are on' do
      expect(mail.to).not_to include(admin_user.email)
    end
  end

  describe '#new_withdrawal_notification' do
    before do
      portfolio
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        amount: 10_000,
        method: 'USDT',
        network: 'TRC20',
        status: 'APPROVED',
        requested_at: 10.days.ago,
        processed_at: 10.days.ago
      )
    end

    let(:mail) { described_class.new_withdrawal_notification(withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to match('Nueva solicitud RETIRO')
      expect(mail.subject).to match('John Doe')
      expect(mail.to).to eq(['contacto@winbit.com.ar'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('John Doe')
      expect(mail.body.encoded).to match('john@example.com')
      expect(mail.body.encoded).to match('Crypto')
      expect(mail.body.encoded).to match('TRC20')
      expect(mail.body.encoded).to match('TQ2abc123...')
    end

    it 'shows balance posterior net of commission wording, not estimado' do
      expect(mail.body.encoded).to match('Balance posterior')
      expect(mail.body.encoded).not_to match(/estimado/i)
      expect(mail.body.encoded).to match('9.500,00 USDT') # 10000 - 500, no fee
    end

    context 'when there is pending profit (CST)' do
      before do
        investor.update!(trading_fee_percentage: 30)
        portfolio.update!(current_balance: 10_000, total_invested: 8_000)
        InvestorRequest.where(investor: investor, request_type: 'DEPOSIT', status: 'APPROVED').delete_all
        InvestorRequest.create!(
          investor: investor,
          request_type: 'DEPOSIT',
          amount: 8_000,
          method: 'USDT',
          network: 'TRC20',
          status: 'APPROVED',
          requested_at: 10.days.ago,
          processed_at: 10.days.ago
        )
      end

      it 'deducts commission from the post-withdrawal balance' do
        # profit 2000 → fee 600 → 10000 - 500 - 600 = 8900
        expect(mail.body.encoded).to match('Balance posterior \(neto de comisión\)')
        expect(mail.body.encoded).to match('Comisión por servicios')
        expect(mail.body.encoded).to match('600,00 USDT')
        expect(mail.body.encoded).to match('8.900,00 USDT')
        expect(mail.body.encoded).not_to match(/estimado/i)
      end
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

  describe '#deposit_approved_notification' do
    before { portfolio.update!(current_balance: 11000) }

    let(:approved_deposit) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        amount: 1000,
        method: 'USDT',
        network: 'TRC20',
        status: 'APPROVED',
        requested_at: Time.current,
        processed_at: Time.current
      )
    end
    let(:mail) { described_class.deposit_approved_notification(approved_deposit) }

    it 'renders the headers' do
      expect(mail.subject).to match('Depósito aprobado de John Doe')
      expect(mail.to).to eq(['contacto@winbit.com.ar'])
    end

    it 'renders the body with deposit details' do
      expect(mail.body.encoded).to match('John Doe')
      expect(mail.body.encoded).to match('USDT')
      expect(mail.body.encoded).to match('11.000,00 USDT')
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
      expect(mail.to).to eq(['contacto@winbit.com.ar'])
    end

    it 'renders the body with withdrawal fee details' do
      expect(mail.body.encoded).to match('John Doe')
      expect(mail.body.encoded).to match('45,75')
    end
  end

  describe 'corrections of a previous request' do
    let(:replaced_request) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        amount: 100,
        method: 'USDT',
        network: 'TRC20',
        status: 'CANCELLED',
        requested_at: Time.zone.local(2026, 11, 8, 10, 30),
        cancelled_at: Time.current
      )
    end

    it 'mentions the replaced deposit in subject and body' do
      mail = described_class.new_deposit_notification(deposit_request, replaced_request)

      expect(mail.subject).to match('corrige una anterior')
      body = mail.body.decoded
      expect(body).to match('Corrige una solicitud anterior')
      expect(body).to match('100,00 USDT')
      expect(body).to match('08/11/2026')
    end

    it 'mentions the replaced withdrawal' do
      portfolio
      mail = described_class.new_withdrawal_notification(withdrawal_request, replaced_request)

      expect(mail.subject).to match('corrige una anterior')
      expect(mail.body.decoded).to match('Corrige una solicitud anterior')
    end

    it 'does not mention a correction when there is none' do
      mail = described_class.new_deposit_notification(deposit_request)

      expect(mail.subject).not_to match('corrige')
      expect(mail.body.decoded).not_to match('Corrige una solicitud anterior')
    end
  end

  describe '#request_cancelled_notification' do
    let(:mail) { described_class.request_cancelled_notification(withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to match('Solicitud cancelada por el inversor')
      expect(mail.subject).to match('RETIRO')
      expect(mail.subject).to match('John Doe')
      expect(mail.to).to eq(['contacto@winbit.com.ar'])
    end

    it 'renders the investor and request details' do
      body = mail.body.decoded
      expect(body).to match('John Doe')
      expect(body).to match('john@example.com')
      expect(body).to match('500,00 USDT')
      expect(body).to match('Crypto \(TRC20\)')
      expect(body).to match(withdrawal_request.id)
    end
  end
end
