# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin outgoing emails', type: :request do
  let!(:admin) { User.create!(email: 'oe-ctl@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'oe-1') }
  let!(:investor) { Investor.create!(email: 'oe-inv@test.com', name: 'OE Investor', status: 'ACTIVE') }
  let!(:draft) do
    OutgoingEmail.create!(investor: investor, kind: 'INVESTOR_WELCOME', to_email: investor.email, subject: 'Hola', body_html: '<p>Hola</p>')
  end
  let!(:sent) do
    OutgoingEmail.create!(investor: investor, kind: 'INVESTOR_WELCOME', to_email: investor.email, subject: 'Viejo',
                          body_html: '<p>x</p>', status: 'SENT')
  end

  context 'when authenticated' do
    before { login_as(admin, scope: :user) }
    after { logout(:user) }

    it 'lists pending emails with the count' do
      get '/api/admin/outgoing_emails'
      json = JSON.parse(response.body)['data']
      expect(response).to have_http_status(:ok)
      expect(json['emails'].map { |e| e['id'] }).to eq([ draft.id ])
      expect(json['pendingCount']).to eq(1)
    end

    it 'lists everything with status=all' do
      get '/api/admin/outgoing_emails', params: { status: 'all' }
      expect(JSON.parse(response.body)['data']['emails'].size).to eq(2)
    end

    it 'shows the body' do
      get "/api/admin/outgoing_emails/#{draft.id}"
      expect(JSON.parse(response.body)['data']['bodyHtml']).to eq('<p>Hola</p>')
    end

    it 'sends a draft' do
      post "/api/admin/outgoing_emails/#{draft.id}/send"
      expect(response).to have_http_status(:no_content)
      expect(draft.reload.status).to eq('SENT')
      expect(ActivityLog.where(action: 'send_outgoing_email').count).to eq(1)
    end

    it 'schedules a draft' do
      post "/api/admin/outgoing_emails/#{draft.id}/schedule"
      expect(response).to have_http_status(:ok)
      expect(draft.reload.status).to eq('SCHEDULED')
      expect(JSON.parse(response.body)['data']['scheduledFor']).to be_present
    end

    it 'cancels a schedule' do
      draft.update!(status: 'SCHEDULED', scheduled_for: 1.hour.from_now)
      post "/api/admin/outgoing_emails/#{draft.id}/unschedule"
      expect(response).to have_http_status(:no_content)
      expect(draft.reload.status).to eq('DRAFT')
    end

    it 'does not schedule a sent email' do
      post "/api/admin/outgoing_emails/#{sent.id}/schedule"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not unschedule a draft that is not scheduled' do
      post "/api/admin/outgoing_emails/#{draft.id}/unschedule"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not resend a sent email' do
      post "/api/admin/outgoing_emails/#{sent.id}/send"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'discards a draft' do
      post "/api/admin/outgoing_emails/#{draft.id}/discard"
      expect(response).to have_http_status(:no_content)
      expect(draft.reload.status).to eq('DISCARDED')
    end

    it 'does not discard a sent email' do
      post "/api/admin/outgoing_emails/#{sent.id}/discard"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for unknown ids' do
      get '/api/admin/outgoing_emails/nope'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'requires authentication' do
    get '/api/admin/outgoing_emails'
    expect(response).to have_http_status(:unauthorized)
  end
end
