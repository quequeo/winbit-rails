# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyAnnexRow, type: :model do
  let(:investor) { Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE') }

  it 'is valid with required attributes' do
    row = described_class.new(
      investor: investor,
      month: Date.new(2026, 1, 1),
      portfolio_value: 1000,
      source: 'spreadsheet',
    )
    expect(row).to be_valid
  end

  it 'requires unique month per investor' do
    described_class.create!(
      investor: investor,
      month: Date.new(2026, 1, 1),
      portfolio_value: 1000,
      source: 'spreadsheet',
    )

    duplicate = described_class.new(
      investor: investor,
      month: Date.new(2026, 1, 1),
      portfolio_value: 1100,
      source: 'spreadsheet',
    )
    expect(duplicate).not_to be_valid
  end
end
