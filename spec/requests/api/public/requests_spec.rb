require 'rails_helper'

RSpec.describe 'Public requests', type: :request do
  it 'POST /api/public/requests creates deposit request with attachment' do
    investor = Investor.create!(email: 'r@example.com', name: 'r', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'USDT',
           network: 'TRC20',
           transactionHash: '0xabc',
           attachmentUrl: 'data:image/png;base64,abc123'
         },
         as: :json

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'status')).to eq('PENDING')
    expect(json.dig('data', 'amount')).to eq(50.0)
    expect(json.dig('data', 'method')).to eq('USDT')
  end

  it 'POST /api/public/requests accepts wrapped params under request key' do
    investor = Investor.create!(email: 'wrapped@example.com', name: 'wrapped', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           request: {
             email: investor.email,
             type: 'DEPOSIT',
             amount: 50,
             method: 'USDT',
             network: 'TRC20',
             transactionHash: '0xwrapped',
             attachmentUrl: 'data:image/png;base64,wrapped'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'status')).to eq('PENDING')
  end

  it 'POST /api/public/requests rejects non-cash deposit without attachment' do
    investor = Investor.create!(email: 'na@example.com', name: 'na', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'CRYPTO'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to include('Attachment is required')
  end

  it 'POST /api/public/requests allows cash deposit without attachment' do
    investor = Investor.create!(email: 'cash@example.com', name: 'cash', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_USD'
         },
         as: :json

    expect(response).to have_http_status(:created)
  end

  it 'POST /api/public/requests stores the asset and returns the currency' do
    investor = Investor.create!(email: 'asset@example.com', name: 'asset', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: { email: investor.email, type: 'WITHDRAWAL', amount: 50, method: 'CRYPTO', asset: 'USDC',
                   network: 'BEP20', walletAddress: '0xabc' },
         as: :json

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig('data', 'currency')).to eq('USDC')
    expect(InvestorRequest.find_by(investor_id: investor.id).asset).to eq('USDC')
  end

  it 'POST /api/public/requests rejects requests in pesos' do
    investor = Investor.create!(email: 'pesos@example.com', name: 'pesos', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    %w[CASH_ARS TRANSFER_ARS].each do |ars_method|
      post '/api/public/requests',
           params: { email: investor.email, type: 'DEPOSIT', amount: 50, method: ars_method },
           as: :json

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('Por el momento no se aceptan operaciones en pesos')
    end
    expect(InvestorRequest.where(investor_id: investor.id).count).to eq(0)
  end

  it 'POST /api/public/requests returns 400 when email is blank' do
    post '/api/public/requests',
         params: {
           email: '',
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_USD'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Email is required')
  end

  it 'POST /api/public/requests returns 400 when email format is invalid' do
    post '/api/public/requests',
         params: {
           email: 'not-an-email',
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_USD'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid email format')
  end

  it 'POST /api/public/requests returns 400 when withdrawal has no portfolio' do
    investor = Investor.create!(email: 'nop@example.com', name: 'nop', status: 'ACTIVE')

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 10,
           method: 'USDT'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('No portfolio found')
  end

  it 'POST /api/public/requests returns 400 with details when validation fails' do
    investor = Investor.create!(email: 'val@example.com', name: 'inv', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'CASH_USD',
           network: 'INVALID_NETWORK'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid request data')
    expect(json['details']).to be_present
    expect(json['details']['network']).to be_present
  end

  it 'POST /api/public/requests returns 400 when amount is invalid' do
    investor = Investor.create!(email: 'inv@example.com', name: 'inv', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: -10,
           method: 'CASH_USD'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid request data')
  end

  it 'POST /api/public/requests returns 400 when amount raises parse error' do
    investor = Investor.create!(email: 'argerr@example.com', name: 'argerr', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: [],
           method: 'CASH_USD'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid request data')
  end

  it 'POST /api/public/requests validates withdrawal balance' do
    investor = Investor.create!(email: 'w@example.com', name: 'w', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 10, total_invested: 10)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 50,
           method: 'USDT',
           network: 'TRC20'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Insufficient balance')
  end

  it 'POST /api/public/requests creates withdrawal request with valid balance' do
    investor = Investor.create!(email: 'withdraw-ok@example.com', name: 'wok', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 1000, total_invested: 1000)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 50,
           method: 'USDT',
           network: 'TRC20'
         },
         as: :json

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'status')).to eq('PENDING')
    expect(json.dig('data', 'type')).to eq('WITHDRAWAL')
  end

  it 'POST /api/public/requests requires wallet destination for CRYPTO withdrawal' do
    investor = Investor.create!(email: 'withdraw-crypto@example.com', name: 'wc', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 1000, total_invested: 1000)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 50,
           method: 'CRYPTO',
           network: 'TRC20'
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Invalid request data')
    expect(json.dig('details', 'wallet_address')).to be_present
  end

  it 'POST /api/public/requests requires lemontag for LEMON_CASH withdrawal' do
    investor = Investor.create!(email: 'lemon-wd@example.com', name: 'lw', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 1000, total_invested: 1000)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 50,
           method: 'LEMON_CASH',
         },
         as: :json

    expect(response).to have_http_status(:bad_request)
    json = JSON.parse(response.body)
    expect(json.dig('details', 'lemontag')).to be_present
  end

  it 'POST /api/public/requests creates LEMON_CASH withdrawal with lemontag' do
    investor = Investor.create!(email: 'lemon-ok@example.com', name: 'lo', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 1000, total_invested: 1000)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 50,
           method: 'LEMON_CASH',
           lemontag: '$winbit_user',
         },
         as: :json

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'lemontag')).to eq('$winbit_user')
    expect(json.dig('data', 'method')).to eq('LEMON_CASH')
  end

  it 'POST /api/public/requests stores wallet destination for CRYPTO withdrawal' do
    investor = Investor.create!(email: 'withdraw-crypto-ok@example.com', name: 'wco', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 1000, total_invested: 1000)

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'WITHDRAWAL',
           amount: 50,
           method: 'CRYPTO',
           network: 'TRC20',
           walletAddress: 'TTvYQZ8....'
         },
         as: :json

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'walletAddress')).to eq('TTvYQZ8....')
    expect(json.dig('data', 'network')).to eq('TRC20')
  end

  it 'POST /api/public/requests continues when email notification fails' do
    investor = Investor.create!(email: 'mailfail@example.com', name: 'mailfail', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)
    allow(InvestorMailer).to receive(:deposit_created).and_raise(StandardError, 'mailer failed')

    post '/api/public/requests',
         params: {
           email: investor.email,
           type: 'DEPOSIT',
           amount: 50,
           method: 'USDT',
           network: 'TRC20',
           attachmentUrl: 'data:image/png;base64,abc123'
         },
         as: :json

    expect(response).to have_http_status(:created)
  end

  it 'POST /api/public/requests accepts unwrapped params without json wrapper' do
    investor = Investor.create!(email: 'plain@example.com', name: 'plain', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)

    post '/api/public/requests', params: {
      email: investor.email,
      type: 'DEPOSIT',
      amount: 50,
      method: 'CASH_USD'
    }

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json.dig('data', 'status')).to eq('PENDING')
  end

  it 'POST /api/public/requests deja registrado en Correos el aviso de solicitud recibida' do
    investor = Investor.create!(email: 'aviso@example.com', name: 'aviso', status: 'ACTIVE')
    Portfolio.create!(investor_id: investor.id, current_balance: 100, total_invested: 100)
    AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'true')

    post '/api/public/requests',
         params: { email: investor.email, type: 'DEPOSIT', amount: 50, method: 'CASH_USD' },
         as: :json

    expect(response).to have_http_status(:created)
    request_id = JSON.parse(response.body).dig('data', 'id')
    email = OutgoingEmail.find_by!(request_id: request_id)
    expect(email.kind).to eq('DEPOSIT_RECEIVED')
    expect(email.status).to eq('SENT')
  end

  def create_pending_request(investor, type: 'DEPOSIT', amount: 100, status: 'PENDING')
    InvestorRequest.create!(
      investor: investor,
      request_type: type,
      amount: amount,
      method: 'USDT',
      network: 'TRC20',
      status: status,
      requested_at: 1.hour.ago
    )
  end

  describe 'POST /api/public/requests/:id/cancel' do
    let(:investor) { Investor.create!(email: 'cancel@example.com', name: 'cancel', status: 'ACTIVE') }
    let(:other_investor) { Investor.create!(email: 'other@example.com', name: 'other', status: 'ACTIVE') }

    before do
      allow(AdminMailer).to receive(:request_cancelled_notification).and_call_original
    end

    it 'cancels a pending request and notifies the admins' do
      req = create_pending_request(investor)

      post "/api/public/requests/#{req.id}/cancel", params: { email: investor.email }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'id')).to eq(req.id)
      expect(json.dig('data', 'status')).to eq('CANCELLED')
      expect(json.dig('data', 'cancelledAt')).to be_present

      req.reload
      expect(req.status).to eq('CANCELLED')
      expect(req.cancelled_at).to be_present
      expect(AdminMailer).to have_received(:request_cancelled_notification).with(req)
    end

    it 'works on the v1 route and with params wrapped under request' do
      req = create_pending_request(investor, type: 'WITHDRAWAL', amount: 20)

      post "/api/public/v1/requests/#{req.id}/cancel", params: { request: { email: investor.email } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(req.reload.status).to eq('CANCELLED')
    end

    it 'returns 404 when the request belongs to another investor' do
      req = create_pending_request(other_investor)

      post "/api/public/requests/#{req.id}/cancel", params: { email: investor.email }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Request not found')
      expect(req.reload.status).to eq('PENDING')
      expect(AdminMailer).not_to have_received(:request_cancelled_notification)
    end

    it 'returns 404 when the email does not exist or the id is unknown' do
      req = create_pending_request(investor)

      post "/api/public/requests/#{req.id}/cancel", params: { email: 'nobody@example.com' }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Request not found')

      post '/api/public/requests/does-not-exist/cancel', params: { email: investor.email }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(req.reload.status).to eq('PENDING')
    end

    it 'returns 422 when the request was already processed' do
      req = create_pending_request(investor, status: 'APPROVED')

      post "/api/public/requests/#{req.id}/cancel", params: { email: investor.email }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('La solicitud ya fue procesada y no se puede cancelar')
      expect(req.reload.status).to eq('APPROVED')
      expect(req.cancelled_at).to be_nil
      expect(AdminMailer).not_to have_received(:request_cancelled_notification)
    end

    it 'returns 422 when the request is already cancelled' do
      req = create_pending_request(investor)
      req.update!(status: 'CANCELLED', cancelled_at: 1.minute.ago)

      post "/api/public/requests/#{req.id}/cancel", params: { email: investor.email }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('La solicitud ya fue procesada y no se puede cancelar')
    end

    it 'still cancels when the admin notification fails' do
      req = create_pending_request(investor)
      allow(AdminMailer).to receive(:request_cancelled_notification).and_raise(StandardError, 'mailer failed')

      post "/api/public/requests/#{req.id}/cancel", params: { email: investor.email }, as: :json

      expect(response).to have_http_status(:ok)
      expect(req.reload.status).to eq('CANCELLED')
    end
  end

  describe 'POST /api/public/requests with replacesRequestId' do
    let(:investor) { Investor.create!(email: 'fix@example.com', name: 'fix', status: 'ACTIVE') }
    let(:other_investor) { Investor.create!(email: 'fix-other@example.com', name: 'fix other', status: 'ACTIVE') }

    before do
      Portfolio.create!(investor_id: investor.id, current_balance: 1000, total_invested: 1000)
      allow(InvestorMailer).to receive(:deposit_created).and_call_original
      allow(AdminMailer).to receive(:new_deposit_notification).and_call_original
      allow(AdminMailer).to receive(:request_cancelled_notification).and_call_original
    end

    def correction_params(old_request, amount: 150)
      {
        email: investor.email,
        type: 'DEPOSIT',
        amount: amount,
        method: 'USDT',
        network: 'TRC20',
        attachmentUrl: 'data:image/png;base64,fix',
        replacesRequestId: old_request.id
      }
    end

    it 'creates the new request and cancels the old one' do
      old = create_pending_request(investor, amount: 100)

      expect do
        post '/api/public/requests', params: correction_params(old), as: :json
      end.to change(InvestorRequest, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'status')).to eq('PENDING')
      expect(json.dig('data', 'amount')).to eq(150.0)

      old.reload
      expect(old.status).to eq('CANCELLED')
      expect(old.cancelled_at).to be_present

      new_request = InvestorRequest.find(json.dig('data', 'id'))
      expect(InvestorMailer).to have_received(:deposit_created).with(investor, new_request)
      expect(AdminMailer).to have_received(:new_deposit_notification).with(new_request, old)
      expect(AdminMailer).not_to have_received(:request_cancelled_notification)
    end

    it 'accepts replacesRequestId wrapped under request' do
      old = create_pending_request(investor, amount: 100)

      post '/api/public/requests', params: { request: correction_params(old) }, as: :json

      expect(response).to have_http_status(:created)
      expect(old.reload.status).to eq('CANCELLED')
    end

    it 'returns 422 and creates nothing when the old request is not pending' do
      old = create_pending_request(investor, amount: 100, status: 'APPROVED')

      expect do
        post '/api/public/requests', params: correction_params(old), as: :json
      end.not_to change(InvestorRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('La solicitud original ya fue procesada y no se puede corregir')
      expect(old.reload.status).to eq('APPROVED')
      expect(AdminMailer).not_to have_received(:new_deposit_notification)
    end

    it 'returns 422 and creates nothing when the correction changes the request type' do
      old = create_pending_request(investor, amount: 100)
      old.update_column(:request_type, 'WITHDRAWAL')

      expect do
        post '/api/public/requests', params: correction_params(old), as: :json
      end.not_to change(InvestorRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to eq('La corrección tiene que ser del mismo tipo que la solicitud original')
      expect(old.reload.status).to eq('PENDING')
    end

    it "returns 404 and creates nothing when the old request is another investor's" do
      old = create_pending_request(other_investor, amount: 100)

      expect do
        post '/api/public/requests', params: correction_params(old), as: :json
      end.not_to change(InvestorRequest, :count)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Request not found')
      expect(old.reload.status).to eq('PENDING')
    end
  end
end
