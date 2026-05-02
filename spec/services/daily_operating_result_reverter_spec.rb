require 'rails_helper'

RSpec.describe DailyOperatingResultReverter do
  let(:admin) { User.create!(email: 'revert_admin@example.com', name: 'Admin', role: 'SUPERADMIN') }

  def create_investor(email:)
    inv = Investor.create!(email: email, name: email.split('@').first, status: 'ACTIVE')
    Portfolio.create!(investor: inv, current_balance: 0, total_invested: 0, accumulated_return_usd: 0, accumulated_return_percent: 0)
    inv
  end

  def add_deposit(inv, amount:, date:)
    t = Time.zone.local(date.year, date.month, date.day, 19, 0, 0)
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

  def portfolio_snapshot(inv)
    p = inv.portfolio
    {
      current_balance: p.current_balance.to_f,
      total_invested: p.total_invested.to_f,
      accumulated_return_usd: p.accumulated_return_usd.to_f,
      accumulated_return_percent: p.accumulated_return_percent.to_f,
      strategy_return_all_percent: p.strategy_return_all_percent&.to_f,
      strategy_return_all_usd: p.strategy_return_all_usd&.to_f,
      strategy_return_ytd_percent: p.strategy_return_ytd_percent&.to_f,
      strategy_return_ytd_usd: p.strategy_return_ytd_usd&.to_f,
    }
  end

  describe '.run!' do
    it 'returns error when there is no daily operating result for that date' do
      result = described_class.run!(date: Date.new(2020, 1, 1), dry_run: true)
      expect(result.ok).to be(false)
      expect(result.error).to include('No hay operativa diaria')
    end

    it 'dry run does not change data and returns preview' do
      d = Date.new(2026, 5, 10)
      travel_to Time.zone.local(2026, 5, 15, 12, 0, 0) do
        inv = create_investor(email: 'dry_revert@example.com')
        add_deposit(inv, amount: 10_000, date: Date.new(2026, 5, 9))
        inv.portfolio.update!(
          strategy_return_all_percent: 5.0,
          strategy_return_all_usd: 500.0,
          strategy_return_ytd_percent: 5.0,
          strategy_return_ytd_usd: 500.0,
        )

        expect(DailyOperatingResultApplicator.new(date: d, percent: 0.5, applied_by: admin).apply).to be(true)

        before = portfolio_snapshot(inv.reload)
        dor = DailyOperatingResult.find_by!(date: d)

        result = described_class.run!(date: d, dry_run: true)
        expect(result.ok).to be(true)
        expect(result.preview[:investors]).to eq(1)
        expect(result.preview[:daily_operating_result_id]).to eq(dor.id)

        expect(DailyOperatingResult.find_by(id: dor.id)).to be_present
        expect(portfolio_snapshot(inv.reload)).to eq(before)
      end
    end

    it 'reverts apply: portfolio and strategy fields match snapshot after recalculation' do
      d = Date.new(2026, 5, 10)
      travel_to Time.zone.local(2026, 5, 15, 12, 0, 0) do
        inv = create_investor(email: 'roundtrip_revert@example.com')
        add_deposit(inv, amount: 10_000, date: Date.new(2026, 5, 9))
        inv.portfolio.update!(
          strategy_return_all_percent: 5.0,
          strategy_return_all_usd: 500.0,
          strategy_return_ytd_percent: 5.0,
          strategy_return_ytd_usd: 500.0,
        )

        snapshot = portfolio_snapshot(inv.reload)

        expect(DailyOperatingResultApplicator.new(date: d, percent: 0.5, applied_by: admin).apply).to be(true)
        expect(portfolio_snapshot(inv.reload)).not_to eq(snapshot)

        result = described_class.run!(date: d, dry_run: false)
        expect(result.ok).to be(true)

        expect(DailyOperatingResult.find_by(date: d)).to be_nil
        expect(PortfolioHistory.where(investor: inv, event: 'OPERATING_RESULT').count).to eq(0)

        expect(portfolio_snapshot(inv.reload)).to eq(snapshot)
      end
    end

    it 'handles strategy_return percent present with nil usd without raising' do
      d = Date.new(2026, 5, 11)
      travel_to Time.zone.local(2026, 5, 15, 12, 0, 0) do
        inv = create_investor(email: 'nil_usd_revert@example.com')
        add_deposit(inv, amount: 1000, date: Date.new(2026, 5, 9))
        inv.portfolio.update!(
          strategy_return_all_percent: 2.0,
          strategy_return_all_usd: nil,
          strategy_return_ytd_percent: 2.0,
          strategy_return_ytd_usd: nil,
        )

        expect(DailyOperatingResultApplicator.new(date: d, percent: 1.0, applied_by: admin).apply).to be(true)

        expect { described_class.run!(date: d, dry_run: false) }.not_to raise_error

        inv.reload
        expect(inv.portfolio.strategy_return_all_usd).to eq(0.0)
        expect(inv.portfolio.strategy_return_ytd_usd).to eq(0.0)
      end
    end
  end
end
