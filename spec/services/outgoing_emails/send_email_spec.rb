# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutgoingEmails::SendEmail do
  let(:admin) { User.create!(email: 'oe-admin@test.com', name: 'Admin', role: 'ADMIN') }
  let(:investor) { Investor.create!(email: 'send@test.com', name: 'Send Inv', status: 'ACTIVE') }
  let(:request) do
    InvestorRequest.create!(investor: investor, request_type: 'DEPOSIT', method: 'USDT', amount: 50,
                            status: 'APPROVED', processed_at: Time.current)
  end
  let(:email) do
    OutgoingEmail.create!(investor: investor, investor_request: request, kind: 'DEPOSIT_APPROVED',
                          to_email: investor.email, subject: 'Winbit | Depósito acreditado', body_html: '<p>Hola</p>')
  end

  before do
    ActionMailer::Base.deliveries.clear
    allow(RequestReceiptPdfs::Generate).to receive(:call) do |request:, **|
      RequestReceiptPdf.create!(request_id: request.id, original_filename: 'x.pdf', byte_size: 8, pdf_data: '%PDF-1.4')
    end
  end

  it 'delivers the stored body with the receipt attached and marks it as sent' do
    described_class.call(outgoing_email: email, sent_by: admin)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ 'send@test.com' ])
    expect(mail.subject).to eq('Winbit | Depósito acreditado')
    expect(mail.attachments.size).to eq(1)
    expect(mail.attachments.first.filename).to start_with('Aporte de capital')
    expect(email.reload).to have_attributes(status: 'SENT', sent_by: admin)
    expect(email.sent_at).to be_present
  end

  it 'refuses to send twice' do
    described_class.call(outgoing_email: email)
    expect { described_class.call(outgoing_email: email) }.to raise_error(StandardError, /ya fue enviado/)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it 'marks the email as FAILED when delivery fails and allows retry' do
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now).and_raise(Net::ReadTimeout)

    expect { described_class.call(outgoing_email: email) }.to raise_error(StandardError, /No se pudo enviar/)
    expect(email.reload.status).to eq('FAILED')
    expect(email.error).to include('Net::ReadTimeout')
    expect(email).to be_pending
  end
end
