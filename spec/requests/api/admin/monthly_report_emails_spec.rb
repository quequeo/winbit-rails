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
      expect(mail.reply_to).to eq([ 'contacto@winbit.com.ar' ])
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

  describe 'scheduled mass send' do
    let(:monday_8am) { Time.find_zone('America/Argentina/Buenos_Aires').local(2026, 11, 2, 8) }

    it 'schedules the send for later without sending anything now' do
      travel_to Time.zone.local(2026, 10, 30, 19) do
        post '/api/admin/v1/monthly_report_emails/schedule', params: {
          month: '2026-07', subject: 'Hola {{nombre}}', body: 'Adjunto', scheduled_for: monday_8am.iso8601
        }
      end

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'status')).to eq('SCHEDULED')
      expect(Time.zone.parse(json.dig('data', 'scheduledFor'))).to eq(monday_8am)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it 'rejects a time in the past and a second schedule for the same month' do
      post '/api/admin/v1/monthly_report_emails/schedule', params: {
        month: '2026-07', subject: 'Hola', body: 'Adjunto', scheduled_for: 1.hour.ago.iso8601
      }
      expect(response).to have_http_status(:unprocessable_content)

      ScheduledMonthlyReportEmail.create!(month: '2026-07', subject: 'a', body: 'b', scheduled_for: 1.day.from_now)
      login_as(admin, scope: :user)
      post '/api/admin/v1/monthly_report_emails/schedule', params: {
        month: '2026-07', subject: 'Hola', body: 'Adjunto', scheduled_for: 2.days.from_now.iso8601
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to include('Ya hay un envío programado')
    end

    it 'lists and cancels a pending schedule' do
      record = ScheduledMonthlyReportEmail.create!(month: '2026-07', subject: 'a', body: 'b', scheduled_for: 1.day.from_now)

      get '/api/admin/v1/monthly_report_emails/schedules', params: { month: '2026-07' }
      expect(JSON.parse(response.body)['data'].map { |r| r['id'] }).to eq([ record.id ])

      login_as(admin, scope: :user)
      post "/api/admin/v1/monthly_report_emails/schedules/#{record.id}/cancel"
      expect(response).to have_http_status(:ok)
      expect(record.reload.status).to eq('CANCELED')

      login_as(admin, scope: :user)
      post "/api/admin/v1/monthly_report_emails/schedules/#{record.id}/cancel"
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'sends to the eligible investors once the time arrives, only once' do
      record = ScheduledMonthlyReportEmail.create!(
        month: '2026-07', subject: 'Hola {{nombre}}', body: 'Adjunto', scheduled_for: monday_8am, scheduled_by: admin
      )

      expect(InvestorMonthlyReportEmails::SendScheduled.call(now: monday_8am - 1.minute)).to eq(0)
      expect(ActionMailer::Base.deliveries).to be_empty

      expect(InvestorMonthlyReportEmails::SendScheduled.call(now: monday_8am + 30.seconds)).to eq(1)
      expect(ActionMailer::Base.deliveries.flat_map(&:to)).to contain_exactly('tulio@test.com', 'ana@test.com')
      expect(record.reload).to have_attributes(status: 'SENT', queued_count: 2, failure_count: 0)
      expect(record.sent_at).to be_present

      expect(InvestorMonthlyReportEmails::SendScheduled.call(now: monday_8am + 2.minutes)).to eq(0)
      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end

    it 'does not send a canceled schedule' do
      ScheduledMonthlyReportEmail.create!(
        month: '2026-07', subject: 'Hola', body: 'Adjunto', scheduled_for: monday_8am, status: 'CANCELED'
      )

      expect(InvestorMonthlyReportEmails::SendScheduled.call(now: monday_8am + 1.minute)).to eq(0)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
