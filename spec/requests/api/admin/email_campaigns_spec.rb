# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Email Campaigns API', type: :request do
  include ActiveJob::TestHelper

  let!(:admin) do
    User.create!(
      email: 'admin@test.com',
      name: 'Admin',
      role: 'ADMIN',
      provider: 'google_oauth2',
      uid: 'camp-admin'
    )
  end
  let!(:investor_a) { Investor.create!(email: 'ana@example.com', name: 'Ana', status: 'ACTIVE') }
  let!(:investor_b) { Investor.create!(email: 'bob@example.com', name: 'Bob', status: 'ACTIVE') }
  let!(:inactive) { Investor.create!(email: 'off@example.com', name: 'Off', status: 'INACTIVE') }

  before do
    login_as(admin, scope: :user)
    Portfolio.create!(investor: investor_a, current_balance: 1000)
    Portfolio.create!(investor: investor_b, current_balance: 2000)
    Portfolio.create!(investor: inactive, current_balance: 500)
    InvestorMonthlyAnnexRow.create!(
      investor: investor_a,
      month: Date.new(2026, 4, 1),
      return_percent: 3.25,
      return_usd: 100,
      portfolio_value: 1000,
      source: 'spreadsheet',
    )
    InvestorMonthlyAnnexRow.create!(
      investor: investor_b,
      month: Date.new(2026, 4, 1),
      return_percent: 1.5,
      return_usd: 50,
      portfolio_value: 2000,
      source: 'spreadsheet',
    )
    AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
    AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, [])
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear
  end

  after { logout(:user) }

  describe 'GET /api/admin/email_campaigns/preview' do
    it 'lists active investors with monthly variables' do
      get '/api/admin/v1/email_campaigns/preview', params: {
        month: '2026-04',
        subject: 'Hola {{nombre}}',
        body: 'Ganancia {{ganancia_pct}} ({{ganancia_usd}})',
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['audienceCount']).to eq(2)
      expect(json['data']['variables']).to include('nombre', 'ganancia_usd', 'ganancia_pct')
      emails = json['data']['recipients'].map { |r| r['email'] }
      expect(emails).to contain_exactly('ana@example.com', 'bob@example.com')
      ana = json['data']['recipients'].find { |r| r['email'] == 'ana@example.com' }
      expect(ana['gananciaUsd']).to eq('$100,00')
      expect(ana['gananciaPct']).to eq('3,25%')
      expect(json['data']['sampleSubject']).to include('Ana').or include('Bob')
    end

    it 'returns 422 for invalid month' do
      get '/api/admin/v1/email_campaigns/preview', params: { month: 'bad' }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST /api/admin/email_campaigns/send_one' do
    it 'queues personalized email even when notifications are disabled' do
      perform_enqueued_jobs do
        post '/api/admin/v1/email_campaigns/send_one', params: {
          month: '2026-04',
          subject: 'Informe {{mes}} — {{nombre}}',
          body: "Hola {{nombre}}\nTu ganancia: {{ganancia_pct}} ({{ganancia_usd}})",
          investor_id: investor_a.id,
        }
      end

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['queuedCount']).to eq(1)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['ana@example.com'])
      expect(mail.subject).to eq('Informe 2026-04 — Ana')
      expect(mail.body.encoded).to include('3,25%')
      expect(mail.body.encoded).to include('$100,00')
      expect(mail.body.encoded).to include('<br>')
      expect(mail.reply_to).to eq(['contacto@winbit.com.ar'])
    end

    it 'attaches a PDF/XLSX for that investor' do
      xlsx = Tempfile.new(['informe-ana', '.xlsx'])
      xlsx.write('PK fake-xlsx-bytes')
      xlsx.rewind

      post '/api/admin/v1/email_campaigns/send_one', params: {
        month: '2026-04',
        subject: 'Informe {{nombre}}',
        body: 'Hola {{nombre}}',
        investor_id: investor_a.id,
        attachment: Rack::Test::UploadedFile.new(
          xlsx.path,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ),
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['queuedCount']).to eq(1)
      expect(json['data']['queued'].first['attached']).to eq(true)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq(File.basename(xlsx.path))
    ensure
      xlsx.close!
    end

    it 'rejects non PDF/XLSX attachments' do
      txt = Tempfile.new(['bad', '.txt'])
      txt.write('hello')
      txt.rewind

      post '/api/admin/v1/email_campaigns/send_one', params: {
        month: '2026-04',
        subject: 'Informe',
        body: 'Hola',
        investor_id: investor_a.id,
        attachment: Rack::Test::UploadedFile.new(txt.path, 'text/plain'),
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ActionMailer::Base.deliveries).to be_empty
    ensure
      txt.close!
    end
  end

  describe 'POST /api/admin/email_campaigns/send_mass' do
    it 'requires confirm' do
      post '/api/admin/v1/email_campaigns/send_mass', params: {
        month: '2026-04',
        subject: 'Hola {{nombre}}',
        body: 'Body',
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'queues emails for all active investors' do
      perform_enqueued_jobs do
        post '/api/admin/v1/email_campaigns/send_mass', params: {
          month: '2026-04',
          subject: 'Hola {{nombre}}',
          body: 'Ganancia {{ganancia_usd}}',
          confirm: true,
        }
      end

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['queuedCount']).to eq(2)
      expect(json['data']['totalAudience']).to eq(2)
      expect(ActionMailer::Base.deliveries.size).to eq(2)
      recipients = ActionMailer::Base.deliveries.flat_map(&:to)
      expect(recipients).to contain_exactly('ana@example.com', 'bob@example.com')
      expect(recipients).not_to include('off@example.com')
    end

    it 'attaches only for investors with uploaded files' do
      pdf = Tempfile.new(['ana', '.pdf'])
      pdf.write('%PDF-1.4 fake')
      pdf.rewind

      perform_enqueued_jobs do
        post '/api/admin/v1/email_campaigns/send_mass', params: {
          month: '2026-04',
          subject: 'Hola {{nombre}}',
          body: 'Body',
          confirm: true,
          attachments: {
            investor_a.id.to_s => Rack::Test::UploadedFile.new(pdf.path, 'application/pdf'),
          },
        }
      end

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['queuedCount']).to eq(2)
      attached_flags = json['data']['queued'].to_h { |row| [row['investor_id'], row['attached']] }
      expect(attached_flags[investor_a.id]).to eq(true)
      expect(attached_flags[investor_b.id]).to eq(false)

      ana_mail = ActionMailer::Base.deliveries.find { |m| m.to == ['ana@example.com'] }
      bob_mail = ActionMailer::Base.deliveries.find { |m| m.to == ['bob@example.com'] }
      expect(ana_mail.attachments.map(&:filename)).to eq([File.basename(pdf.path)])
      expect(bob_mail.attachments).to be_empty
    ensure
      pdf.close!
    end
  end

  describe 'choosing recipients' do
    let(:base) { { month: '2026-04', subject: 'Hola {{nombre}}', body: 'Texto', confirm: true } }

    it 'sends only to the chosen investors and logs each one as sent' do
      post '/api/admin/v1/email_campaigns/send_mass',
           params: base.merge(audience: 'selected', investor_ids: [ investor_b.id ])

      expect(response).to have_http_status(:ok)
      expect(ActionMailer::Base.deliveries.flat_map(&:to)).to eq([ 'bob@example.com' ])
      logged = OutgoingEmail.find_by!(kind: 'CAMPAIGN')
      expect(logged).to have_attributes(investor: investor_b, status: 'SENT', subject: 'Hola Bob')
      expect(logged.sent_at).to be_present
      expect(OutgoingEmail.pending).to be_empty
    end

    it 'sends nothing when the selection is empty' do
      post '/api/admin/v1/email_campaigns/send_mass', params: base.merge(audience: 'selected')

      expect(response).to have_http_status(:unprocessable_content)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it 'rejects investors that are not active' do
      post '/api/admin/v1/email_campaigns/send_mass',
           params: base.merge(audience: 'selected', investor_ids: [ investor_a.id, inactive.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it 'never sends to everyone from an empty list' do
      EmailCampaigns::Send.call(month: '2026-04', subject: 'Hola', body: 'Texto', investor_ids: [])

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe 'the app button' do
    let(:base) { { month: '2026-04', subject: 'Hola', body: 'Texto', investor_id: investor_a.id } }

    it 'is left out unless requested' do
      post '/api/admin/v1/email_campaigns/send_one', params: base

      expect(ActionMailer::Base.deliveries.last.body.to_s).not_to include('Ver mi cuenta en la app')
    end

    it 'is added when requested' do
      post '/api/admin/v1/email_campaigns/send_one', params: base.merge(app_button: true)

      expect(ActionMailer::Base.deliveries.last.body.to_s).to include('Ver mi cuenta en la app')
    end
  end

  describe 'test sends' do
    it 'goes to the given address and is not logged' do
      post '/api/admin/v1/email_campaigns/send_one', params: {
        month: '2026-04', subject: 'Hola {{nombre}}', body: 'Texto', investor_id: investor_a.id,
        test_email: 'flor@example.com'
      }

      expect(response).to have_http_status(:ok)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ 'flor@example.com' ])
      expect(mail.subject).to eq('Hola Ana')
      expect(OutgoingEmail.count).to eq(0)
    end

    it 'rejects an invalid address' do
      post '/api/admin/v1/email_campaigns/send_one', params: {
        month: '2026-04', subject: 'Hola', body: 'Texto', investor_id: investor_a.id, test_email: 'no-es-mail'
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe 'scheduling' do
    let(:monday_8am) { 3.days.from_now.change(usec: 0) }
    let(:base) do
      { month: '2026-04', subject: 'Hola {{nombre}}', body: 'Texto', scheduled_for: monday_8am.iso8601 }
    end

    it 'schedules for everyone without sending anything yet' do
      post '/api/admin/v1/email_campaigns/schedule', params: base

      expect(response).to have_http_status(:created)
      record = ScheduledCampaignEmail.last
      expect(record).to have_attributes(status: 'SCHEDULED', investor_ids: nil, scheduled_by: admin, app_button: false)
      expect(ActionMailer::Base.deliveries).to be_empty

      login_as(admin, scope: :user)
      get '/api/admin/v1/email_campaigns/schedules'
      expect(JSON.parse(response.body)['data'].first['id']).to eq(record.id)
    end

    it 'rejects a date in the past' do
      post '/api/admin/v1/email_campaigns/schedule', params: base.merge(scheduled_for: 1.hour.ago.iso8601)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ScheduledCampaignEmail.count).to eq(0)
    end

    it 'rejects an empty selection' do
      post '/api/admin/v1/email_campaigns/schedule', params: base.merge(audience: 'selected')

      expect(response).to have_http_status(:unprocessable_content)
      expect(ScheduledCampaignEmail.count).to eq(0)
    end

    it 'sends to everyone active once the time arrives, only once, and logs it' do
      record = ScheduledCampaignEmail.create!(
        month: '2026-04', subject: 'Hola {{nombre}}', body: 'Texto', scheduled_for: monday_8am, scheduled_by: admin
      )

      expect(EmailCampaigns::SendScheduled.call(now: monday_8am - 1.minute)).to eq(0)
      expect(ActionMailer::Base.deliveries).to be_empty

      expect(EmailCampaigns::SendScheduled.call(now: monday_8am + 30.seconds)).to eq(1)
      expect(ActionMailer::Base.deliveries.flat_map(&:to)).to contain_exactly('ana@example.com', 'bob@example.com')
      expect(record.reload).to have_attributes(status: 'SENT', queued_count: 2, failure_count: 0)
      expect(OutgoingEmail.where(kind: 'CAMPAIGN', status: 'SENT').count).to eq(2)

      expect(EmailCampaigns::SendScheduled.call(now: monday_8am + 2.minutes)).to eq(0)
      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end

    it 'sends only to the chosen investors' do
      ScheduledCampaignEmail.create!(
        month: '2026-04', subject: 'Hola', body: 'Texto', scheduled_for: monday_8am, investor_ids: [ investor_a.id ]
      )

      EmailCampaigns::SendScheduled.call(now: monday_8am + 1.minute)

      expect(ActionMailer::Base.deliveries.flat_map(&:to)).to eq([ 'ana@example.com' ])
    end

    it 'does not send a canceled schedule' do
      record = ScheduledCampaignEmail.create!(
        month: '2026-04', subject: 'Hola', body: 'Texto', scheduled_for: monday_8am
      )

      post "/api/admin/v1/email_campaigns/schedules/#{record.id}/cancel"
      expect(response).to have_http_status(:ok)
      expect(record.reload.status).to eq('CANCELED')

      expect(EmailCampaigns::SendScheduled.call(now: monday_8am + 1.minute)).to eq(0)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
