# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin monthly report emails API', type: :request do
  let!(:admin) do
    User.create!(
      email: 'admin@test.com',
      name: 'Admin',
      role: 'ADMIN',
      provider: 'google_oauth2',
      uid: 'report-email-admin'
    )
  end
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }
  let!(:ana) { Investor.create!(email: 'ana@test.com', name: 'Ana Pérez', status: 'ACTIVE') }
  let!(:jaime) { Investor.create!(email: 'monitoapps@gmail.com', name: 'Jaime Empty', status: 'ACTIVE') }
  let!(:inactive) { Investor.create!(email: 'old@test.com', name: 'Inactivo', status: 'INACTIVE') }

  before do
    login_as(admin, scope: :user)
    Portfolio.create!(investor: tulio, current_balance: 5000)
    Portfolio.create!(investor: ana, current_balance: 2000)
    Portfolio.create!(investor: jaime, current_balance: 0)
    Portfolio.create!(investor: inactive, current_balance: 800)

    create_pdf(tulio, filename: 'Reporte julio - TULIO CAPPARELLI.pdf', body: '%PDF-1.4 tulio')
    create_pdf(ana, filename: 'Reporte julio - ANA PEREZ.pdf', body: '%PDF-1.4 ana')
    create_pdf(jaime, filename: 'Reporte julio - JAIME.pdf', body: '%PDF-1.4 jaime')
    create_pdf(inactive, filename: 'Reporte julio - INACTIVO.pdf', body: '%PDF-1.4 old')

    AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
    AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, [])
    ActionMailer::Base.deliveries.clear
  end

  after { logout(:user) }

  def create_pdf(investor, filename:, body:)
    InvestorMonthlyReportPdf.create!(
      investor: investor,
      month: '2026-07',
      original_filename: filename,
      content_type: 'application/pdf',
      byte_size: body.bytesize,
      pdf_data: body
    )
  end

  describe 'GET /api/admin/v1/monthly_report_emails/preview' do
    it 'lists eligible recipients and skipped investors' do
      get '/api/admin/v1/monthly_report_emails/preview', params: {
        month: '2026-07',
        subject: 'Hola {{nombre}}',
        body: 'Adjunto el reporte de {{mes}}'
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'audienceCount')).to eq(2)
      emails = json.dig('data', 'recipients').map { |row| row['email'] }
      expect(emails).to contain_exactly('tulio@test.com', 'ana@test.com')
      tulio_row = json.dig('data', 'recipients').find { |row| row['email'] == 'tulio@test.com' }
      expect(tulio_row['hasPdf']).to be(true)
      expect(tulio_row['balance']).to eq(5000.0)
      expect(tulio_row['pdfFilename']).to eq('Reporte julio 2026 - TULIO CAPPARELLI.pdf')
      skipped = json.dig('data', 'skipped').index_by { |row| row['email'] }
      expect(skipped['monitoapps@gmail.com']['skipReason']).to eq('zero_balance')
      expect(skipped['old@test.com']['skipReason']).to eq('inactive')
      expect(json.dig('data', 'sampleSubject')).to include('Tulio').or include('Ana')
    end

    it 'returns 422 for invalid month' do
      get '/api/admin/v1/monthly_report_emails/preview', params: { month: 'bad' }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST /api/admin/v1/monthly_report_emails/send_one' do
    it 'sends to an eligible investor with the stored PDF even when notifications are off' do
      post '/api/admin/v1/monthly_report_emails/send_one', params: {
        month: '2026-07',
        subject: 'Informe {{mes}} — {{nombre}}',
        body: "Hola {{nombre}}\nVa el PDF",
        investor_id: tulio.id
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'queuedCount')).to eq(1)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ 'tulio@test.com' ])
      expect(mail.subject).to eq('Informe 2026-07 — Tulio Capparelli')
      expect(mail.attachments.first.filename).to eq('Reporte julio 2026 - TULIO CAPPARELLI.pdf')
      expect(mail.reply_to).to eq([ 'winbit.cfds@gmail.com' ])
    end

    it 'rejects zero-balance investors' do
      post '/api/admin/v1/monthly_report_emails/send_one', params: {
        month: '2026-07',
        subject: 'Informe',
        body: 'Hola',
        investor_id: jaime.id
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('balance')
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe 'POST /api/admin/v1/monthly_report_emails/send_mass' do
    it 'requires confirm' do
      post '/api/admin/v1/monthly_report_emails/send_mass', params: {
        month: '2026-07',
        subject: 'Hola {{nombre}}',
        body: 'Body'
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'sends only to eligible investors' do
      post '/api/admin/v1/monthly_report_emails/send_mass', params: {
        month: '2026-07',
        subject: 'Hola {{nombre}}',
        body: 'Adjunto',
        confirm: true
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'queuedCount')).to eq(2)
      recipients = ActionMailer::Base.deliveries.flat_map(&:to)
      expect(recipients).to contain_exactly('tulio@test.com', 'ana@test.com')
      expect(recipients).not_to include('monitoapps@gmail.com', 'old@test.com')
    end
  end
end
