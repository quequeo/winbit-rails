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
      lemontag: '$lemonuser',
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
      expect(mail.subject).to start_with('Winbit | Ingreso procesado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('fue procesado el ingreso')
      expect(mail.body.encoded).to match('comprobante de ingreso')
    end

    it 'always expresses amounts in USDT, even for USDC deposits' do
      deposit_request.update!(method: 'USDC')
      usdc_mail = described_class.deposit_approved(investor, deposit_request)

      expect(usdc_mail.subject).to include('USDT')
      expect(usdc_mail.subject).not_to include('USDC')
    end
  end

  describe '#deposit_rejected' do
    let(:reason) { 'Comprobante inválido' }
    let(:mail) { described_class.deposit_rejected(investor, deposit_request, reason) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Ingreso no procesado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/no pudimos procesar el ingreso/)
      expect(mail.body.encoded).to match(/Comprobante inválido/)
    end

    it 'hides the generic admin note as a reason' do
      generic = described_class.deposit_rejected(investor, deposit_request, 'Rechazado por el administrador')
      expect(generic.body.encoded).not_to match(/Motivo/)
    end
  end

  describe '#withdrawal_created' do
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

    let(:mail) { described_class.withdrawal_created(investor, withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Solicitud de retiro recibida |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('retiro')
      expect(mail.body.encoded).to match('16:00')
    end

    it 'shows balance posterior without estimado when there is no fee' do
      expect(mail.body.encoded).to match('Balance posterior')
      expect(mail.body.encoded).not_to match(/estimado/i)
      expect(mail.body.encoded).to match('9.500,00 USDT') # 10000 - 500
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

      it 'shows balance net of commission' do
        # profit 2000 → fee 600 → balance after = 10000 - 500 - 600 = 8900
        expect(mail.body.encoded).to match('Balance posterior \(neto de comisión\)')
        expect(mail.body.encoded).to match('Comisión por servicios')
        expect(mail.body.encoded).to match('600,00 USDT')
        expect(mail.body.encoded).to match('8.900,00 USDT')
        expect(mail.body.encoded).not_to match(/estimado/i)
      end
    end
  end

  describe '#withdrawal_approved' do
    before { portfolio } # Ensure portfolio exists

    let(:mail) { described_class.withdrawal_approved(investor, withdrawal_request) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Retiro procesado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/fue procesado el retiro/)
      expect(mail.body.encoded).to match(/comprobante de egreso/)
      expect(mail.body.encoded).not_to match(/comisión por servicios de trading/)
    end

    it 'includes withdrawal trading fee details when provided' do
      fee_data = {
        fee_amount: BigDecimal('30.50'),
        fee_percentage: BigDecimal('30')
      }
      mail_with_fee = described_class.withdrawal_approved(investor, withdrawal_request, fee_data)

      expect(mail_with_fee.body.encoded).to match(/comisión por servicios de trading/)
      expect(mail_with_fee.body.encoded).to match(/30,50 USDT/)
      expect(mail_with_fee.body.encoded).to match(/30% de la rentabilidad acumulada/)
    end
  end

  describe '#withdrawal_rejected' do
    let(:reason) { 'Lemontag incorrecto' }
    let(:mail) { described_class.withdrawal_rejected(investor, withdrawal_request, reason) }

    it 'renders the headers' do
      expect(mail.subject).to start_with('Winbit | Retiro no procesado |')
      expect(mail.to).to eq(['john@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/no pudimos procesar el retiro/)
      expect(mail.body.encoded).to match(/Lemontag incorrecto/)
      expect(mail.body.encoded).to match(/capital no tuvo cambios/)
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
