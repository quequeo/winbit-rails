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
      expect(json['data']['summary']).to have_key('netContributedUsd')
      expect(json['data']['summary']).to have_key('yearOpeningDate')
      expect(json['data']['operations']).to be_present
      expect(json['data']['operations']).to include('trades', 'assets', 'count', 'positive', 'negative', 'breakEven', 'netResultUsd')
    end

    it 'includes the month trades in operations' do
      admin_op = User.create!(email: 'admin-ops@test.com', name: 'Ops Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'ops-1')
      StrategyOperation.create!(
        operation_date: Date.new(2026, 4, 10), asset: 'MNQ', direction: 'LONG',
        opened_at: '10:00', closed_at: '10:30', result_usd: 50, ratio: 1.2,
        source: 'manual', result_label: 'POSITIVO', created_by: admin_op
      )
      # The investor's own daily result drives which trades appear/their $ amount.
      PortfolioHistory.create!(
        investor: investor, event: 'OPERATING_RESULT', amount: 32.5,
        previous_balance: 6484, new_balance: 6516.5,
        date: Time.zone.local(2026, 4, 10, 19, 0, 0), status: 'COMPLETED',
      )

      get "/api/admin/v1/investors/#{investor.id}/monthly_report", params: { month: '2026-04' }

      json = JSON.parse(response.body)
      operations = json.dig('data', 'operations')
      expect(operations['count']).to eq(1)
      expect(operations['trades'].first['asset']).to eq('MNQ')
      expect(operations['trades'].first['resultUsd']).to eq(32.5)
      expect(operations['assets']).to eq([{ 'code' => 'MNQ', 'name' => 'Micro E-mini Nasdaq-100' }])
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
