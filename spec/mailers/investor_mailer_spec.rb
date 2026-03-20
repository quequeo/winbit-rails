# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMailer, type: :mailer do
  let(:investor) { Investor.create!(name: 'John Doe', email: 'john@example.com', status: 'ACTIVE') }
  let(:portfolio) { Portfolio.create!(investor: investor, current_balance: 10000, total_invested: 10000) }
  let(:deposit_request) do
    InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      amount: 1000,
      method: 'USDT',
      network: 'TRC20',
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
      status: 'PENDING',
      requested_at: Time.current
    )
  end

  before do
    # Enable notifications for these tests
    AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'true')
  end

  after do
    # Clean up settings
    AppSetting.where(key: [
      AppSetting::INVESTOR_NOTIFICATIONS_ENABLED,
      AppSetting::INVESTOR_EMAIL_WHITELIST
    ]).destroy_all
  end

  describe '#deposit_created' do
    let(:mail) { described_class.deposit_created(investor, deposit_request) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Solicitud de depósito recibida |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/solicitud de depósito/)
      expect(mail.body.encoded).to match(/USDT/)
    end
  end

  describe '#deposit_approved' do
    before { portfolio } # Ensure portfolio exists

    let(:mail) { described_class.deposit_approved(investor, deposit_request) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Depósito acreditado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('acreditados')
      expect(mail.body.encoded).to match('panel de inversión')
    end
  end

  describe '#deposit_rejected' do
    let(:reason) { 'Comprobante inválido' }
    let(:mail) { described_class.deposit_rejected(investor, deposit_request, reason) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Depósito rechazado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/rechazada/)
      expect(mail.body.encoded).to match(/Comprobante inválido/)
    end
  end

  describe '#withdrawal_created' do
    let(:mail) { described_class.withdrawal_created(investor, withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Solicitud de retiro recibida |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('retiro')
      expect(mail.body.encoded).to match('16:00')
    end
  end

  describe '#withdrawal_approved' do
    before { portfolio } # Ensure portfolio exists

    let(:mail) { described_class.withdrawal_approved(investor, withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Retiro aprobado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/aprobada/)
      expect(mail.body.encoded).to match(/Monto enviado/)
    end

    it 'includes withdrawal trading fee details when provided' do
      fee_data = {
        fee_amount: BigDecimal('30.50')
      }
      mail_with_fee = described_class.withdrawal_approved(investor, withdrawal_request, fee_data)

      expect(mail_with_fee.body.encoded).to match(/Comisión por retiro/)
      expect(mail_with_fee.body.encoded).to match(/Total deducido de tu cuenta/)
    end
  end

  describe '#withdrawal_rejected' do
    let(:reason) { 'Lemontag incorrecto' }
    let(:mail) { described_class.withdrawal_rejected(investor, withdrawal_request, reason) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Retiro rechazado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/rechazada/)
      expect(mail.body.encoded).to match(/Lemontag incorrecto/)
      expect(mail.body.encoded).to match(/saldo no fue modificado/)
    end
  end

  describe '#deposit_created with TRANSFER_ARS' do
    let(:ars_request) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        amount: 150_000,
        method: 'TRANSFER_ARS',
        status: 'PENDING',
        requested_at: Time.current
      )
    end
    let(:mail) { described_class.deposit_created(investor, ars_request) }

    it 'uses ARS in the subject amount' do
      expect(mail.subject).to include('ARS')
      expect(mail.subject).not_to include('USDT')
    end
  end
end
