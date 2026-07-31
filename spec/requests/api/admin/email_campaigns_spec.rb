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
  end
end
