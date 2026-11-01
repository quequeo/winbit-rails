# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RequestReceiptPdfs::DocumentData do
  let!(:admin) { User.create!(email: 'dd-admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'dd-1') }
  let(:investor) { Investor.create!(email: 'luis@example.com', name: 'Luis Matías Crocci', status: 'ACTIVE', trading_fee_percentage: 25) }
  let(:processed_at) { Time.zone.local(2026, 10, 15, 19, 0, 0) }

  def build_request(attrs = {})
    InvestorRequest.create!({
      investor: investor, request_type: 'WITHDRAWAL', method: 'USDT', amount: 144.74, operation_number: 'R-2026-0142',
      network: 'TRC20', wallet_address: 'TXyz12abcdefghklmnop', status: 'APPROVED', processed_at: processed_at,
      requested_at: Time.zone.local(2026, 10, 14, 10)
    }.merge(attrs))
  end

  def history(event, amount, new_balance, date)
    previous = event == 'DEPOSIT' ? new_balance - amount : new_balance + amount
    PortfolioHistory.create!(investor_id: investor.id, event: event, amount: amount, previous_balance: previous,
                             new_balance: new_balance, status: 'COMPLETED', date: date)
  end

  it 'builds a partial withdrawal with the fee in USD, the real currency and the abbreviated wallet' do
    req = build_request
    TradingFee.create!(
      investor: investor, applied_by: admin, source: 'WITHDRAWAL', withdrawal_request_id: req.id, withdrawal_amount: 144.74,
      profit_amount: 138.96, fee_percentage: 25, fee_amount: 34.74, applied_at: processed_at,
      period_start: processed_at.to_date, period_end: processed_at.to_date + 1
    )

    data = described_class.call(request: req, balance_after: '4722.76')

    expect(data).to include(
      kind: :retiro, title: 'Comprobante de retiro', file_kind: 'Retiro', operation_number: 'R-2026-0142',
      investor_name: 'Luis Matías Crocci', first_name: 'Luis', date_long: '15 de octubre de 2026', date_short: '15/10/2026',
      requested_on: '14/10/2026', amount_label: '144,74 USDT', fee_label: 'USD 34,74', fee_percentage: '25',
      capital_label: 'USD 4.722,76', medium: 'USDT · Red TRC20 · Wallet del inversor TXyz12…klmnop'
    )
  end

  it 'leaves the fee out when there was no commission and takes the capital from the tagged history' do
    req = build_request(method: 'USDC')
    PortfolioHistory.create!(investor_id: investor.id, event: 'WITHDRAWAL', amount: 144.74, previous_balance: 1144.74,
                             new_balance: 1000, status: 'COMPLETED', date: processed_at, operation_number: 'R-2026-0142')

    data = described_class.call(request: req)

    expect(data).to include(fee_label: nil, amount_label: '144,74 USDC', capital_label: 'USD 1.000,00')
  end

  it 'detects the total withdrawal and computes the net result since the first deposit' do
    history('DEPOSIT', 2000, 2000, Time.zone.local(2025, 10, 2, 19))
    history('WITHDRAWAL', 2312.40, 0, processed_at)
    req = build_request(amount: 2312.40, method: 'SWIFT', network: nil, wallet_address: nil, asset: 'USD')

    data = described_class.call(request: req, balance_after: '0')

    expect(data).to include(kind: :retiro_total, title: 'Comprobante de retiro total', amount_label: 'USD 2.312,40',
                            medium: 'Transferencia bancaria en USD', capital_label: 'USD 0,00')
    expect(data[:result]).to include(label: '+USD 312,40', percentage: '15,62', since: '02/10/2025', since_short: '2/10/2025')
  end

  it 'marks the first deposit as the initial contribution with the account type and the Winbit wallet' do
    DepositOption.create!(category: 'CRYPTO', label: 'USDT TRC20', currency: 'USDT',
                          details: { 'address' => 'TWnb45abcdefghij8xQr', 'network' => 'TRC20' })
    req = build_request(request_type: 'DEPOSIT', operation_number: 'A-2026-0031', amount: 2000, wallet_address: nil)

    data = described_class.call(request: req, balance_after: '2000')

    expect(data).to include(kind: :aporte, title: 'Comprobante de aporte inicial', file_kind: 'Aporte',
                            medium: 'USDT · Red TRC20 · Wallet Winbit TWnb45…8xQr')
    expect(data[:account_type]).to eq(name: 'Inversor', percentage: '25')
  end

  it 'treats later deposits as ingresos' do
    req = build_request(request_type: 'DEPOSIT', operation_number: 'I-2026-0087', method: 'CASH_USD', network: nil, wallet_address: nil)

    expect(described_class.call(request: req, balance_after: '5000')).to include(kind: :ingreso, medium: 'Efectivo en USD')
  end
end
