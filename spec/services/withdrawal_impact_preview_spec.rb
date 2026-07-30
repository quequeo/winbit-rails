# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WithdrawalImpactPreview do
  def build_investor_with_profit(balance:, total_invested:, fee_pct: 30)
    inv = Investor.create!(
      email: "preview-#{SecureRandom.hex(4)}@example.com",
      name: 'Preview',
      status: 'ACTIVE',
      trading_fee_percentage: fee_pct
    )
    Portfolio.create!(
      investor_id: inv.id,
      current_balance: balance,
      total_invested: total_invested,
      accumulated_return_usd: balance - total_invested,
      accumulated_return_percent: 0,
      annual_return_usd: 0,
      annual_return_percent: 0
    )
    InvestorRequest.create!(
      investor: inv,
      request_type: 'DEPOSIT',
      amount: total_invested,
      method: 'USDT',
      network: 'TRC20',
      status: 'APPROVED',
      requested_at: 10.days.ago,
      processed_at: 10.days.ago
    )
    inv
  end

  it 'returns fee and balance net of commission when there is pending profit' do
    # Deposit 8000, balance 10_000 → pending profit 2000 → fee 30% = 600
    investor = build_investor_with_profit(balance: 10_000, total_invested: 8_000)

    result = described_class.call(investor: investor, amount: 5_000)

    expect(result).to be_computable
    expect(result).to be_has_fee
    expect(result.fee_amount).to eq(BigDecimal('600'))
    expect(result.balance_after).to eq(BigDecimal('4400')) # 10000 - 5000 - 600
    expect(result.pending_profit).to eq(BigDecimal('2000'))
  end

  it 'returns balance after amount only when there is no pending profit' do
    investor = build_investor_with_profit(balance: 10_000, total_invested: 10_000)

    result = described_class.call(investor: investor, amount: 500)

    expect(result).to be_computable
    expect(result).not_to be_has_fee
    expect(result.fee_amount).to eq(BigDecimal('0'))
    expect(result.balance_after).to eq(BigDecimal('9500'))
  end

  it 'marks preview as not computable without portfolio' do
    inv = Investor.create!(
      email: 'noportfolio@example.com',
      name: 'No Portfolio',
      status: 'ACTIVE',
      trading_fee_percentage: 30
    )

    result = described_class.call(investor: inv, amount: 100)

    expect(result).not_to be_computable
    expect(result.balance_after).to be_nil
  end
end
