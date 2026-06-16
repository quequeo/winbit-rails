require 'rails_helper'

RSpec.describe DailyOperatingUsdTotals do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '1') }
  let!(:investor) { Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 10_000, total_invested: 10_000) }

  it 'sums OPERATING_RESULT amounts for a date' do
    day = Date.new(2025, 6, 10)
    at_time = described_class.movement_time(day)

    PortfolioHistory.create!(
      investor: investor,
      event: 'OPERATING_RESULT',
      amount: 250.5,
      previous_balance: 10_000,
      new_balance: 10_250.5,
      status: 'COMPLETED',
      date: at_time,
    )

    expect(described_class.for_date(day)).to eq(250.5)
  end

  it 'returns totals for multiple dates' do
    day1 = Date.new(2025, 6, 11)
    day2 = Date.new(2025, 6, 12)

    [day1, day2].each_with_index do |day, index|
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: 100 * (index + 1),
        previous_balance: 10_000,
        new_balance: 10_000 + (100 * (index + 1)),
        status: 'COMPLETED',
        date: described_class.movement_time(day),
      )
    end

    totals = described_class.for_dates([day1, day2])
    expect(totals[day1]).to eq(100.0)
    expect(totals[day2]).to eq(200.0)
  end
end
