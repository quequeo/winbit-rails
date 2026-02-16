require 'rails_helper'

RSpec.describe 'Admin requests list', type: :request do
  before do
    user = User.create!(email: 'admin@example.com', role: 'ADMIN')
    sign_in user, scope: :user
  end

  describe 'GET /api/admin/requests' do
    let!(:investor1) { Investor.create!(email: 'investor1@example.com', name: 'Investor One', status: 'ACTIVE') }
    let!(:investor2) { Investor.create!(email: 'investor2@example.com', name: 'Investor Two', status: 'ACTIVE') }

    let!(:pending_deposit) do
      InvestorRequest.create!(
        investor_id: investor1.id,
        request_type: 'DEPOSIT',
        amount: 1000,
        method: 'USDT',
        status: 'PENDING',
        requested_at: 2.days.ago,
        attachment_url: 'https://example.com/receipt.jpg'
      )
    end

    let!(:approved_withdrawal) do
      InvestorRequest.create!(
        investor_id: investor2.id,
        request_type: 'WITHDRAWAL',
        amount: 500,
        method: 'SWIFT',
        status: 'APPROVED',
        requested_at: 1.day.ago,
        processed_at: Time.current
      )
    end

    let!(:rejected_deposit) do
      InvestorRequest.create!(
        investor_id: investor1.id,
        request_type: 'DEPOSIT',
        amount: 200,
        method: 'USDT',
        status: 'REJECTED',
        requested_at: 3.days.ago,
        processed_at: 2.days.ago
      )
    end

    let!(:another_pending) do
      InvestorRequest.create!(
        investor_id: investor2.id,
        request_type: 'WITHDRAWAL',
        amount: 300,
        method: 'USDT',
        status: 'PENDING',
        requested_at: Time.current
      )
    end

    it 'returns all requests ordered by requested_at desc' do
      get '/api/admin/requests', params: { per_page: 200 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['requests'].length).to eq(4)
      expect(json['data']['pendingCount']).to eq(2)

      # Check ordering (most recent first)
      expect(json['data']['requests'][0]['id']).to eq(another_pending.id)
      expect(json['data']['requests'][3]['id']).to eq(rejected_deposit.id)
    end

    it 'returns requests with correct structure and investor data' do
      get '/api/admin/requests', params: { per_page: 200 }

      json = JSON.parse(response.body)
      first_request = json['data']['requests'][0]

      expect(first_request).to include(
        'id' => another_pending.id,
        'investorId' => investor2.id,
        'type' => 'WITHDRAWAL',
        'amount' => 300.0,
        'method' => 'USDT',
        'status' => 'PENDING'
      )

      expect(first_request['investor']).to include(
        'name' => 'Investor Two',
        'email' => 'investor2@example.com'
      )
    end

    it 'filters by status when status param is provided' do
      get '/api/admin/requests', params: { status: 'PENDING', per_page: 200 }

      json = JSON.parse(response.body)

      expect(json['data']['requests'].length).to eq(2)
      expect(json['data']['requests'].all? { |r| r['status'] == 'PENDING' }).to be true
    end

    it 'filters by type when type param is provided' do
      get '/api/admin/requests', params: { type: 'DEPOSIT', per_page: 200 }

      json = JSON.parse(response.body)

      expect(json['data']['requests'].length).to eq(2)
      expect(json['data']['requests'].all? { |r| r['type'] == 'DEPOSIT' }).to be true
    end

    it 'filters by both status and type when both params are provided' do
      get '/api/admin/requests', params: { status: 'PENDING', type: 'DEPOSIT', per_page: 200 }

      json = JSON.parse(response.body)

      expect(json['data']['requests'].length).to eq(1)
      expect(json['data']['requests'][0]['id']).to eq(pending_deposit.id)
      expect(json['data']['requests'][0]['status']).to eq('PENDING')
      expect(json['data']['requests'][0]['type']).to eq('DEPOSIT')
    end

    it 'includes attachment_url when present' do
      get '/api/admin/requests', params: { per_page: 200 }

      json = JSON.parse(response.body)
      request_with_attachment = json['data']['requests'].find { |r| r['id'] == pending_deposit.id }

      expect(request_with_attachment['attachmentUrl']).to eq('https://example.com/receipt.jpg')
    end

    it 'includes processed_at when request is processed' do
      get '/api/admin/requests', params: { per_page: 200 }

      json = JSON.parse(response.body)
      processed_request = json['data']['requests'].find { |r| r['id'] == approved_withdrawal.id }

      expect(processed_request['processedAt']).not_to be_nil
    end

    it 'returns correct pending count regardless of filters' do
      get '/api/admin/requests', params: { status: 'APPROVED', per_page: 200 }

      json = JSON.parse(response.body)

      # Only approved requests in the list
      expect(json['data']['requests'].length).to eq(1)
      # But pending count should still be total pending
      expect(json['data']['pendingCount']).to eq(2)
    end

    context 'when no requests exist' do
      before do
        InvestorRequest.destroy_all
      end

      it 'returns empty array and zero pending count' do
        get '/api/admin/requests', params: { per_page: 200 }

        json = JSON.parse(response.body)

        expect(json['data']['requests']).to eq([])
        expect(json['data']['pendingCount']).to eq(0)
      end
    end

    context 'when filter matches no requests' do
      it 'returns empty array but correct pending count' do
        get '/api/admin/requests', params: { status: 'CANCELLED', per_page: 200 }

        json = JSON.parse(response.body)

        expect(json['data']['requests']).to eq([])
        expect(json['data']['pendingCount']).to eq(2)
      end
    end
  end
end
