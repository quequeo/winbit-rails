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


  let(:admin) { User.create!(email: 'mailer-admin@test.com', name: 'Admin', role: 'ADMIN') }

  def html(mail)
    mail.html_part.decoded
  end

  def text(mail)
    mail.text_part.decoded
  end

  def ar(*args)
    MailPersonalization::ZONE.local(*args)
  end

  def history(event, amount, new_balance, date, operation_number: nil)
    previous = event == 'DEPOSIT' ? new_balance - amount : new_balance + amount
    PortfolioHistory.create!(investor_id: investor.id, event: event, amount: amount, previous_balance: previous,
                             new_balance: new_balance, status: 'COMPLETED', date: date, operation_number: operation_number)
  end

  def approve(request, balance_after:, operation_number:)
    request.update!(status: 'APPROVED', processed_at: ar(2026, 10, 15, 19), operation_number: operation_number,
                    requested_at: ar(2026, 10, 14, 10))
    history(request.request_type, request.amount, balance_after, request.processed_at, operation_number: operation_number)
  end

  describe '#deposit_created' do
    let(:mail) { described_class.deposit_created(investor, deposit_request) }

    it 'confirms the request with the date and time, in HTML and plain text' do
      deposit_request.update!(requested_at: ar(2026, 10, 14, 10, 5))

      expect(mail.subject).to eq('Winbit | Solicitud de ingreso recibida | 1.000,00 USDT')
      expect(mail.to).to eq([ 'john@example.com' ])
      expect(html(mail)).to include('Hola, John, ¿cómo estás?', 'el 14/10/2026 a las 10:05', 'El equipo de Winbit')
      expect(text(mail)).to include('Recibimos tu solicitud de ingreso por 1.000,00 USDT')
    end
  end

  describe '#deposit_approved' do
    before { portfolio }

    it 'sends the welcome mail for the initial contribution' do
      approve(deposit_request, balance_after: 1000, operation_number: 'A-2026-0001')
      mail = described_class.deposit_approved(investor, deposit_request)

      expect(mail.subject).to eq('Winbit | Bienvenida y aporte de capital | 1.000,00 USDT')
      expect(html(mail)).to include('Te damos la bienvenida a Winbit', 'recibido el 15/10/2026', 'Tipo de cuenta: <strong>Inversor</strong>',
                                    'la comisión es de USD 30,00', 'Ver mi cuenta en la app')
      expect(text(mail)).to include('Capital inicial: USD 1.000,00')
    end

    it 'confirms a later deposit in its real currency with the capital in USD' do
      deposit_request.update!(method: 'USDC')
      approve(deposit_request, balance_after: 5000, operation_number: 'I-2026-0002')
      mail = described_class.deposit_approved(investor, deposit_request)

      expect(mail.subject).to eq('Winbit | Ingreso acreditado | 1.000,00 USDC')
      expect(html(mail)).to include('Te confirmamos que se acreditó el ingreso de <strong>1.000,00 USDC</strong> recibido el 15/10/2026',
                                    'tu capital administrado es de <strong>USD 5.000,00</strong>, y ya se refleja en tu cuenta',
                                    'Ante cualquier consulta, escribinos por')
      expect(html(mail)).not_to match(/Buenos días|Buenas tardes|egreso|Winbit Finance/)
    end
  end

  describe '#deposit_rejected' do
    let(:reason) { 'Comprobante inválido' }
    let(:mail) { described_class.deposit_rejected(investor, deposit_request, reason) }

    it 'renders the headers and the reason' do
      expect(mail.subject).to start_with('Winbit | Ingreso no procesado |')
      expect(html(mail)).to include('no pudimos procesar el ingreso', 'Comprobante inválido')
    end

    it 'hides the generic admin note as a reason' do
      generic = described_class.deposit_rejected(investor, deposit_request, 'Rechazado por el administrador')
      expect(html(generic)).not_to include('Motivo')
    end
  end

  describe '#withdrawal_created' do
    let(:mail) { described_class.withdrawal_created(investor, withdrawal_request) }

    it 'tells when the request will be processed' do
      withdrawal_request.update!(requested_at: ar(2026, 10, 14, 17, 30))

      expect(mail.subject).to eq('Winbit | Solicitud de retiro recibida | 500,00 USDT')
      expect(html(mail)).to include('el 14/10/2026 a las 17:30', 'a partir de las 8:00 del próximo día hábil',
                                    'Si no reconocés esta solicitud')
    end
  end

  describe '#withdrawal_approved' do
    before { portfolio }

    it 'reports the fee in USD from the same record as the receipt' do
      approve(withdrawal_request, balance_after: 4722.76, operation_number: 'R-2026-0001')
      TradingFee.create!(investor: investor, applied_by: admin, source: 'WITHDRAWAL', withdrawal_request_id: withdrawal_request.id,
                         withdrawal_amount: 500, profit_amount: 100, fee_percentage: 30, fee_amount: 30,
                         applied_at: withdrawal_request.processed_at, period_start: Date.new(2026, 10, 15), period_end: Date.new(2026, 10, 16))
      mail = described_class.withdrawal_approved(investor, withdrawal_request)

      expect(mail.subject).to eq('Winbit | Retiro procesado | 500,00 USDT')
      expect(html(mail)).to include('se procesó el retiro de <strong>500,00 USDT</strong> solicitado el 14/10/2026',
                                    'comprobante de retiro', 'comisión de gestión de <strong>USD 30,00</strong>',
                                    'equivalente al 30% de la nueva rentabilidad positiva generada desde la última liquidación',
                                    'USD 4.722,76')
    end

    it 'leaves the fee paragraph out when there was no commission' do
      approve(withdrawal_request, balance_after: 9500, operation_number: 'R-2026-0001')

      expect(html(described_class.withdrawal_approved(investor, withdrawal_request))).not_to include('comisión de gestión')
    end

    it 'sends the farewell mail with the net result on a total withdrawal' do
      history('DEPOSIT', 400, 400, ar(2025, 10, 2, 19))
      approve(withdrawal_request, balance_after: 0, operation_number: 'R-2026-0001')
      mail = described_class.withdrawal_approved(investor, withdrawal_request)

      expect(mail.subject).to eq('Winbit | Retiro total procesado | 500,00 USDT')
      expect(html(mail)).to include('retiro total de tu capital', 'Desde tu primer aporte, el 02/10/2025',
                                    '<strong>+USD 100,00</strong> (<strong>25%</strong>)')
    end

    it 'skips the result when it was not positive' do
      history('DEPOSIT', 800, 800, ar(2025, 10, 2, 19))
      approve(withdrawal_request, balance_after: 0, operation_number: 'R-2026-0001')

      expect(html(described_class.withdrawal_approved(investor, withdrawal_request)))
        .to include('vas a encontrar el detalle del retiro').and(satisfy { |body| !body.include?('resultado neto') })
    end
  end

  describe '#withdrawal_rejected' do
    let(:mail) { described_class.withdrawal_rejected(investor, withdrawal_request, 'Lemontag incorrecto') }

    it 'renders the reason and says the capital did not change' do
      expect(mail.subject).to start_with('Winbit | Retiro no procesado |')
      expect(html(mail)).to include('no pudimos procesar el retiro', 'Lemontag incorrecto', 'capital no tuvo cambios')
    end
  end
end
