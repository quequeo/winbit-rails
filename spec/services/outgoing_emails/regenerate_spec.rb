# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutgoingEmails::Regenerate do
  let(:investor) { Investor.create!(email: 'regen@test.com', name: 'Luis Matías Crocci', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 4722.76, total_invested: 4000) }
  let(:request) do
    InvestorRequest.create!(investor: investor, request_type: 'WITHDRAWAL', method: 'USDT', amount: 144.74, network: 'TRC20',
                            wallet_address: 'TXyz12abcdefghklmnop', status: 'APPROVED', processed_at: Time.current,
                            operation_number: 'R-2026-0150')
  end
  let(:scheduled_for) { 1.hour.from_now.change(usec: 0) }
  let(:email) do
    OutgoingEmail.create!(investor: investor, investor_request: request, kind: 'WITHDRAWAL_APPROVED', to_email: investor.email,
                          subject: 'Winbit | Retiro procesado | 144,74 USDT', status: 'SCHEDULED', scheduled_for: scheduled_for,
                          body_html: "<p>#{MailPersonalization::GREETING_TOKEN}, Luis ¿cómo estás?</p><p>comprobante de egreso</p>")
  end

  before { allow(RequestReceiptPdfs::Generate).to receive(:call) }

  it 'rebuilds the body with the current texts, regenerates the receipt and keeps the schedule' do
    described_class.call(outgoing_email: email)

    expect(email.reload.body_html).to include('Hola, Luis, ¿cómo estás?', 'comprobante de retiro')
    expect(email.body_html).not_to include('egreso')
    expect(email.body_text).to include('Te confirmamos que se procesó el retiro de 144,74 USDT')
    expect(email).to have_attributes(status: 'SCHEDULED', scheduled_for: scheduled_for)
    expect(RequestReceiptPdfs::Generate).to have_received(:call).with(request: request)
  end

  it 'refuses emails that already left' do
    email.update!(status: 'SENT')

    expect { described_class.call(outgoing_email: email) }.to raise_error(described_class::NotRegenerable, /ya fue enviado/)
  end

  it 'refuses emails without a receipt' do
    email.update!(kind: 'WITHDRAWAL_REJECTED')

    expect { described_class.call(outgoing_email: email) }.to raise_error(described_class::NotRegenerable)
  end
end
