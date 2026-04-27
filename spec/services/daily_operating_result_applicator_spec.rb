require 'rails_helper'

RSpec.describe DailyOperatingResultApplicator do
  let(:admin) { User.create!(email: 'admin_test@example.com', name: 'Admin', role: 'SUPERADMIN') }

  def create_investor(email:)
    inv = Investor.create!(email: email, name: email.split('@').first, status: 'ACTIVE')
    Portfolio.create!(investor: inv, current_balance: 0, total_invested: 0, accumulated_return_usd: 0, accumulated_return_percent: 0)
    inv
  end

  def add_deposit(inv, amount:, date:)
    t = Time.zone.local(date.year, date.month, date.day, 19, 0, 0) # after 18hs
    portfolio = inv.portfolio
    prev = BigDecimal(portfolio.current_balance.to_s)
    amt = BigDecimal(amount.to_s).round(2, :half_up)
    after = (prev + amt).round(2, :half_up)

    PortfolioHistory.create!(
      investor: inv,
      event: 'DEPOSIT',
      amount: amt.to_f,
      previous_balance: prev.to_f,
      new_balance: after.to_f,
      status: 'COMPLETED',
      date: t,
    )

    total_invested = BigDecimal(portfolio.total_invested.to_s) + amt
    portfolio.update!(
      current_balance: after.to_f,
      total_invested: total_invested.to_f,
      accumulated_return_usd: (after - total_invested).round(2, :half_up).to_f,
      accumulated_return_percent: (total_invested.positive? ? ((after - total_invested) / total_invested * 100).round(4, :half_up) : 0).to_f,
    )
  end

  it 'does not include investors who only deposit after the operating day when previewing previous day' do
    inv = create_investor(email: 'new_inv@example.com')

    # Deposit happens on Jan 22 after 18hs
    add_deposit(inv, amount: 1000, date: Date.new(2026, 1, 22))

    # Preview for Jan 21 should not include this investor because balance at 17:00 Jan 21 is 0
    applicator = described_class.new(date: Date.new(2026, 1, 21), percent: 1.0, applied_by: admin)
    data = applicator.preview

    expect(data).to be_present
    ids = data[:investors].map { |r| r[:investor_id] }
    expect(ids).not_to include(inv.id)
  end

  it 'applies when raw deposits minus withdrawals is negative but sequential total_invested floors at zero' do
    d = Date.new(2026, 5, 10)
    at_time = Time.zone.local(d.year, d.month, d.day, 17, 0, 0)
    inv = create_investor(email: 'bad_history_dor@example.com')
    inv.portfolio.update!(
      current_balance: 50,
      total_invested: 100,
      accumulated_return_usd: -50,
      accumulated_return_percent: -50.0,
    )

    PortfolioHistory.create!(
      investor: inv, event: 'DEPOSIT', amount: 100.0,
      previous_balance: 0, new_balance: 100.0, status: 'COMPLETED',
      date: at_time - 3.hours,
    )
    PortfolioHistory.create!(
      investor: inv, event: 'OPERATING_RESULT', amount: 500.0,
      previous_balance: 100.0, new_balance: 600.0, status: 'COMPLETED',
      date: at_time - 2.hours,
    )
    PortfolioHistory.create!(
      investor: inv, event: 'WITHDRAWAL', amount: 550.0,
      previous_balance: 600.0, new_balance: 50.0, status: 'COMPLETED',
      date: at_time - 1.hour,
    )

    applicator = described_class.new(date: d, percent: 1.0, applied_by: admin)
    expect(applicator.apply).to be(true)
    expect(DailyOperatingResult.find_by(date: d)).to be_present
    inv.reload
    expect(PortfolioRecalculator.total_invested_breakdown(inv.id)[:total_invested]).to eq(BigDecimal('100'))
  end
end
