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
    expect(mail.reply_to).to eq([ 'winbit.cfds@gmail.com' ])
  end
end
