# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Investor Monthly Reports API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345') }
  let!(:investor) { Investor.create!(email: 'eugenio.carrio7@gmail.com', name: 'Eugenio Carrió', status: 'ACTIVE') }

  before do
    login_as(admin, scope: :user)
    Portfolio.create!(investor: investor, current_balance: 6484)
    InvestorMonthlyAnnexRow.create!(
      investor: investor,
      month: Date.new(2026, 4, 1),
      return_percent: 2.5,
      return_usd: 158,
      portfolio_value: 6484,
      source: 'spreadsheet',
    )
  end

  after { logout(:user) }

  describe 'GET /api/admin/investors/:id/monthly_report' do
    it 'returns monthly report JSON' do
      get "/api/admin/v1/investors/#{investor.id}/monthly_report", params: { month: '2026-04' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['reportMonth']).to eq('2026-04')
      expect(json['data']['investor']['email']).to eq('eugenio.carrio7@gmail.com')
      expect(json['data']['annexRows']).to be_an(Array)
    end

    it 'returns 422 for invalid month' do
      get "/api/admin/v1/investors/#{investor.id}/monthly_report", params: { month: 'bad' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 for unknown investor' do
      get '/api/admin/v1/investors/999999/monthly_report', params: { month: '2026-04' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
