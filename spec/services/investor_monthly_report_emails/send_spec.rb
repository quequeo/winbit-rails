# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportEmails::Send do
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }
  let!(:jaime) { Investor.create!(email: 'monitoapps@gmail.com', name: 'Jaime Empty', status: 'ACTIVE') }

  before do
    Portfolio.create!(investor: tulio, current_balance: 5000)
    Portfolio.create!(investor: jaime, current_balance: 0)
    InvestorMonthlyReportPdf.create!(
      investor: tulio,
      month: '2026-07',
      original_filename: 'viejo.pdf',
      content_type: 'application/pdf',
      byte_size: 14,
      pdf_data: '%PDF-1.4 tulio'
    )
    InvestorMonthlyReportPdf.create!(
      investor: jaime,
      month: '2026-07',
      original_filename: 'jaime.pdf',
      content_type: 'application/pdf',
      byte_size: 14,
      pdf_data: '%PDF-1.4 jaime'
    )
    AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
    AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, [])
    ActionMailer::Base.deliveries.clear
  end

  it 'sends only to eligible investors with the stored PDF and canonical filename' do
    result = described_class.call(
      month: '2026-07',
      subject: 'Hola {{nombre}}',
      body: 'Adjunto tu reporte'
    )

    expect(result.queued.size).to eq(1)
    expect(result.queued.first[:email]).to eq('tulio@test.com')
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ 'tulio@test.com' ])
    expect(mail.subject).to eq('Hola Tulio Capparelli')
    expect(mail.attachments.size).to eq(1)
    expect(mail.attachments.first.filename).to eq('Reporte julio 2026 - TULIO CAPPARELLI.pdf')
    expect(mail.attachments.first.body.decoded).to eq('%PDF-1.4 tulio')
    expect(mail.reply_to).to eq([ 'contacto@winbit.com.ar' ])
  end

  it 'logs each delivered report as sent, so it shows in the history' do
    described_class.call(month: '2026-07', subject: 'Hola {{nombre}}', body: 'Adjunto tu reporte')

    logged = OutgoingEmail.find_by!(kind: 'MONTHLY_REPORT')
    expect(OutgoingEmail.count).to eq(1)
    expect(logged).to have_attributes(
      investor: tulio,
      status: 'SENT',
      to_email: 'tulio@test.com',
      subject: 'Hola Tulio Capparelli'
    )
    expect(logged.sent_at).to be_present
    expect(logged.body_html).to include('Adjunto tu reporte')
    expect(OutgoingEmail.pending).to be_empty
  end

  it 'does not log test sends' do
    described_class.call(
      month: '2026-07', subject: 'Hola', body: 'Prueba', investor_ids: [ tulio.id ], to_email: 'prueba@test.com'
    )

    expect(ActionMailer::Base.deliveries.last.to).to eq([ 'prueba@test.com' ])
    expect(OutgoingEmail.count).to eq(0)
  end

  it 'keeps the delivery as successful when logging fails' do
    allow(OutgoingEmail).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(OutgoingEmail.new))

    result = described_class.call(month: '2026-07', subject: 'Hola', body: 'Adjunto')

    expect(result.queued.size).to eq(1)
    expect(result.failures).to be_empty
  end
end
