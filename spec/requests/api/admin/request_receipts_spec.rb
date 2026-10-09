# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin request receipts', type: :request do
  let!(:admin) { User.create!(email: 'rr-admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'rr-1') }
  let(:investor) { Investor.create!(email: 'rr@example.com', name: 'RR Investor', status: 'ACTIVE') }
  let(:req) do
    InvestorRequest.create!(
      investor: investor, request_type: 'WITHDRAWAL', method: 'USDT', amount: 10,
      network: 'TRC20', wallet_address: 'TX', status: 'APPROVED', processed_at: Time.current
    )
  end

  context 'when authenticated' do
    before { login_as(admin, scope: :user) }
    after { logout(:user) }

    it 'returns the stored PDF' do
      RequestReceiptPdf.create!(request_id: req.id, original_filename: 'c.pdf', byte_size: 8, pdf_data: '%PDF-1.4')
      get "/api/admin/requests/#{req.id}/receipt"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/pdf')
      expect(response.body).to start_with('%PDF')
    end

    it 'generates it on demand when missing' do
      allow(RequestReceiptPdfs::Generate).to receive(:call) do |request:, **|
        RequestReceiptPdf.create!(request_id: request.id, original_filename: 'c.pdf', byte_size: 8, pdf_data: '%PDF-1.4')
      end
      get "/api/admin/requests/#{req.id}/receipt"
      expect(response).to have_http_status(:ok)
    end

    it 'rejects pending requests' do
      req.update!(status: 'PENDING')
      get "/api/admin/requests/#{req.id}/receipt"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for unknown requests' do
      get '/api/admin/requests/nope/receipt'
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'requires authentication' do
    get "/api/admin/requests/#{req.id}/receipt"
    expect(response).to have_http_status(:unauthorized)
  end
end
