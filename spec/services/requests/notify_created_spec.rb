# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Requests::NotifyCreated do
  let(:investor) { Investor.create!(name: 'Ana Pérez', email: 'ana@example.com', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 10_000, total_invested: 10_000) }

  def build_request(type)
    InvestorRequest.create!(
      investor: investor,
      request_type: type,
      amount: 500,
      method: 'CRYPTO',
      asset: 'USDT',
      network: 'TRC20',
      wallet_address: (type == 'WITHDRAWAL' ? 'TWallet123' : nil),
      attachment_url: (type == 'DEPOSIT' ? 'https://example.com/comprobante.png' : nil),
      status: 'PENDING',
      requested_at: Time.current
    )
  end

  let(:deliveries) { ActionMailer::Base.deliveries }

  before do
    AppSetting.where(key: [
      AppSetting::INVESTOR_NOTIFICATIONS_ENABLED,
      AppSetting::INVESTOR_EMAIL_WHITELIST,
    ]).destroy_all
    deliveries.clear
  end

  context 'con las notificaciones a inversores habilitadas' do
    before { AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'true') }

    it 'manda en el momento el aviso al inversor y a operaciones, y registra el del inversor en Correos' do
      request = build_request('DEPOSIT')

      described_class.call(request: request)

      expect(deliveries.map(&:to)).to contain_exactly(['ana@example.com'], [AdminMailer::OPERATIONS_INBOX])
      email = OutgoingEmail.find_by!(request_id: request.id)
      expect(email.kind).to eq('DEPOSIT_RECEIVED')
      expect(email.status).to eq('SENT')
      expect(email.sent_at).to be_present
      expect(email.to_email).to eq('ana@example.com')
      expect(email.subject).to include('Solicitud de ingreso recibida')
      expect(email.body_html).to be_present
    end

    it 'registra el retiro con su propio tipo' do
      request = build_request('WITHDRAWAL')

      described_class.call(request: request)

      email = OutgoingEmail.find_by!(request_id: request.id)
      expect(email.kind).to eq('WITHDRAWAL_RECEIVED')
      expect(email.status).to eq('SENT')
      expect(email.subject).to include('Solicitud de retiro recibida')
    end

    it 'si falla el envío al inversor, lo deja en Correos como fallido (para reenviar) y avisa igual a operaciones' do
      request = build_request('DEPOSIT')
      allow(InvestorMailer).to receive(:reviewed_message).and_raise(Net::SMTPServerBusy, 'busy')

      expect { described_class.call(request: request) }.not_to raise_error

      email = OutgoingEmail.find_by!(request_id: request.id)
      expect(email.status).to eq('FAILED')
      expect(email.error).to include('busy')
      expect(email).to be_pending
      expect(deliveries.map(&:to)).to eq([[AdminMailer::OPERATIONS_INBOX]])
    end

    it 'si falla algo inesperado al enviar, también queda como fallido' do
      request = build_request('DEPOSIT')
      allow(InvestorMailer).to receive(:reviewed_message).and_raise(StandardError, 'boom')

      expect { described_class.call(request: request) }.not_to raise_error

      expect(OutgoingEmail.find_by!(request_id: request.id).status).to eq('FAILED')
    end

    it 'si falla el aviso a operaciones, no rompe nada' do
      request = build_request('WITHDRAWAL')
      allow(AdminMailer).to receive(:new_withdrawal_notification).and_raise(StandardError, 'smtp caído')

      expect { described_class.call(request: request) }.not_to raise_error

      expect(OutgoingEmail.find_by!(request_id: request.id).status).to eq('SENT')
    end
  end

  context 'con las notificaciones a inversores apagadas' do
    before { AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false') }

    it 'no le escribe al inversor, lo registra como no enviado con el motivo y avisa a operaciones' do
      request = build_request('DEPOSIT')

      described_class.call(request: request)

      expect(deliveries.map(&:to)).to eq([[AdminMailer::OPERATIONS_INBOX]])
      email = OutgoingEmail.find_by!(request_id: request.id)
      expect(email.status).to eq('SKIPPED')
      expect(email.error).to include('notificaciones a inversores están apagadas')
      expect(email).not_to be_pending
      expect(email.subject).to include('Solicitud de ingreso recibida')
    end

    it 'sí le escribe si está en la lista de prueba' do
      AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['ana@example.com'])
      request = build_request('WITHDRAWAL')

      described_class.call(request: request)

      expect(OutgoingEmail.find_by!(request_id: request.id).status).to eq('SENT')
      expect(deliveries.map(&:to)).to include(['ana@example.com'])
    end
  end
end
