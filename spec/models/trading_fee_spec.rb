require 'rails_helper'

RSpec.describe TradingFee, type: :model do
  let(:admin) { User.create!(email: 'admin-trading-fee@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'tf-admin') }
  let(:investor) { Investor.create!(email: 'investor-trading-fee@test.com', name: 'Investor', status: 'ACTIVE') }

  def build_fee(attrs = {})
    TradingFee.new(
      {
        investor: investor,
        applied_by: admin,
        period_start: Date.new(2025, 10, 1),
        period_end: Date.new(2025, 12, 31),
        profit_amount: 1000,
        fee_percentage: 30,
        fee_amount: 300,
        applied_at: Time.current
      }.merge(attrs)
    )
  end

  it 'is valid with valid attributes' do
    expect(build_fee).to be_valid
  end

  it 'requires period_end to be after period_start' do
    fee = build_fee(period_end: Date.new(2025, 10, 1))
    expect(fee).not_to be_valid
    expect(fee.errors[:period_end]).to include('must be after period start')
  end

  it 'validates fee_percentage range' do
    fee = build_fee(fee_percentage: 101)
    expect(fee).not_to be_valid
    expect(fee.errors[:fee_percentage]).to be_present
  end

  it 'prevents overlapping active fees for the same investor' do
    build_fee.save!
    overlapping = build_fee(period_start: Date.new(2025, 11, 1), period_end: Date.new(2026, 1, 31))

    expect(overlapping).not_to be_valid
    expect(overlapping.errors[:base]).to include('Trading fee already exists for this period')
  end

  it 'allows overlapping when previous fee is voided' do
    fee = build_fee
    fee.update!(voided_at: Time.current, voided_by: admin)

    overlapping = build_fee(period_start: Date.new(2025, 11, 1), period_end: Date.new(2026, 1, 31))
    expect(overlapping).to be_valid
  end

  it 'includes only non-voided fees in active scope' do
    active_fee = build_fee
    active_fee.save!
    voided_fee = build_fee(period_start: Date.new(2025, 7, 1), period_end: Date.new(2025, 9, 30))
    voided_fee.save!
    voided_fee.update!(voided_at: Time.current, voided_by: admin)

    expect(TradingFee.active).to include(active_fee)
    expect(TradingFee.active).not_to include(voided_fee)
  end
end
