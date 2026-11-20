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

    it 'reschedules at a chosen date and time' do
      draft.update!(status: 'SCHEDULED', scheduled_for: 1.hour.from_now)
      post "/api/admin/outgoing_emails/#{draft.id}/schedule", params: { scheduled_for: '2099-11-02T10:30:00-03:00' }
      expect(response).to have_http_status(:ok)
      expect(draft.reload.scheduled_for).to eq(Time.zone.parse('2099-11-02T13:30:00Z'))
    end

    it 'rejects a past date and time' do
      post "/api/admin/outgoing_emails/#{draft.id}/schedule", params: { scheduled_for: 1.hour.ago.iso8601 }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(draft.reload.status).to eq('DRAFT')
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

    it 'updates a receipt draft to the current format' do
      request = InvestorRequest.create!(investor: investor, request_type: 'DEPOSIT', method: 'USDT', amount: 100,
                                        status: 'APPROVED', processed_at: Time.current, operation_number: 'A-2026-0001')
      draft.update!(kind: 'DEPOSIT_APPROVED', investor_request: request)
      allow(RequestReceiptPdfs::Generate).to receive(:call)

      post "/api/admin/outgoing_emails/#{draft.id}/regenerate"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['bodyHtml']).to include('Nos alegra mucho que nos elijas')
      expect(ActivityLog.where(action: 'regenerate_outgoing_email').count).to eq(1)
    end

    describe 'mail de alta' do
      let(:request) do
        InvestorRequest.create!(investor: investor, request_type: 'DEPOSIT', method: 'USDT', amount: 100,
                                status: 'APPROVED', processed_at: Time.current, operation_number: 'A-2026-0001')
      end
      let(:welcome) { OutgoingEmails::Draft.call(kind: 'DEPOSIT_APPROVED', investor: investor, request: request) }

      it 'shows what is missing and blocks sending' do
        get "/api/admin/outgoing_emails/#{welcome.id}"
        data = JSON.parse(response.body)['data']
        expect(data['welcome']).to include('greeting' => nil, 'usesPassword' => true,
                                           'guideFilename' => 'Winbit_Guia_de_bienvenida.pdf')
        expect(data['welcome']['missing']).to eq([ 'elegí "Bienvenido" o "Bienvenida"',
                                                   'generá la contraseña inicial con "Aplicar al correo"' ])

        login_as(admin, scope: :user)
        post "/api/admin/outgoing_emails/#{welcome.id}/send"
        expect(response).to have_http_status(:unprocessable_entity)
        expect(welcome.reload.status).to eq('DRAFT')
      end

      it 'completes the greeting and then lets it be scheduled' do
        post "/api/admin/outgoing_emails/#{welcome.id}/welcome", params: { greeting: 'bienvenida' }

        expect(response).to have_http_status(:ok)
        expect(welcome.reload.subject).to eq('Oe, bienvenida a Winbit')
        expect(JSON.parse(response.body)['data']['welcome']['missing']).to eq([])
        expect(ActivityLog.where(action: 'complete_welcome_email').count).to eq(1)

        login_as(admin, scope: :user)
        post "/api/admin/outgoing_emails/#{welcome.id}/schedule"
        expect(welcome.reload.status).to eq('SCHEDULED')
      end

      it 'generates the initial password, assigns it to the investor and puts it in the mail' do
        post "/api/admin/outgoing_emails/#{welcome.id}/welcome", params: { greeting: 'bienvenido' }

        expect(response).to have_http_status(:ok)
        password = welcome.reload.body_html[%r{contraseña inicial es <strong>([^<]+)</strong>}, 1]
        expect(password).to match(/\A[a-zA-Z2-9]{10}\z/)
        expect(investor.reload.authenticate(password)).to be_truthy
        expect(welcome.body_html).not_to include(WelcomeEmail::PASSWORD_MARK)
      end

      it 'does not touch the password of a Gmail investor' do
        investor.update!(email: 'oe-inv@gmail.com')

        post "/api/admin/outgoing_emails/#{welcome.id}/welcome", params: { greeting: 'bienvenido' }

        expect(investor.reload.password_digest).to be_nil
        expect(welcome.reload.body_html).to include('Acceder con Google')
      end

      it 'keeps the chosen greeting when the format is updated' do
        allow(RequestReceiptPdfs::Generate).to receive(:call)
        post "/api/admin/outgoing_emails/#{welcome.id}/welcome", params: { greeting: 'bienvenida' }
        login_as(admin, scope: :user)
        post "/api/admin/outgoing_emails/#{welcome.id}/regenerate"

        expect(welcome.reload.subject).to eq('Oe, bienvenida a Winbit')
      end

      it 'downloads the welcome guide' do
        allow(WelcomeGuidePdfs::Generate).to receive(:call).and_return('%PDF-guide')

        get "/api/admin/outgoing_emails/#{welcome.id}/welcome_guide"

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq('%PDF-guide')
        expect(response.headers['Content-Disposition']).to include('Winbit_Guia_de_bienvenida.pdf')
      end

      it 'rejects other emails' do
        post "/api/admin/outgoing_emails/#{draft.id}/welcome", params: { greeting: 'bienvenida' }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'does not update emails without a receipt' do
      post "/api/admin/outgoing_emails/#{draft.id}/regenerate"
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
