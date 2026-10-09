# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RequestReceiptPdfs::DocumentData do
  let!(:admin) { User.create!(email: 'dd-admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'dd-1') }
  let(:investor) { Investor.create!(email: 'lisandro@example.com', name: 'Lisandro Filardi', status: 'ACTIVE') }
  let(:processed_at) { Time.zone.local(2026, 10, 9, 19, 0, 0) }

  def build_request(attrs = {})
    InvestorRequest.create!({
      investor: investor, request_type: 'WITHDRAWAL', method: 'USDT', amount: 166.25,
      network: 'TRC20', wallet_address: 'TXyz123', status: 'APPROVED', processed_at: processed_at
    }.merge(attrs))
  end

  it 'formats a withdrawal with fee and destination' do
    req = build_request
    TradingFee.create!(
      investor: investor, applied_by: admin, source: 'WITHDRAWAL', withdrawal_request_id: req.id, withdrawal_amount: 166.25,
      profit_amount: 100, fee_percentage: 30, fee_amount: 30, applied_at: processed_at,
      period_start: processed_at.to_date, period_end: processed_at.to_date + 1
    )

    data = described_class.call(request: req, balance_after: '4637.02')

    expect(data).to include(
      withdrawal: true, investor_name: 'LISANDRO FILARDI', date_label: '9 de octubre de 2026',
      unit: 'USDT', amount: '166,25', fee: '30,00', fee_percentage: '30', capital: '4.637,02'
    )
    expect(data[:destination]).to include('TRC20', 'TXyz123')
  end

  it 'omits fee on a deposit and falls back to USD unit' do
    req = build_request(request_type: 'DEPOSIT', method: 'SWIFT', network: nil, wallet_address: nil)
    Portfolio.create!(investor: investor, current_balance: 1500.5, total_invested: 1500.5)

    data = described_class.call(request: req)

    expect(data).to include(withdrawal: false, fee: nil, destination: nil, unit: 'USD', capital: '1.500,50')
  end
end
