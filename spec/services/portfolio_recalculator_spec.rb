require 'rails_helper'

RSpec.describe PortfolioRecalculator do
  let(:investor) { Investor.create!(email: 'recalc_spec@example.com', name: 'Recalc', status: 'ACTIVE') }
  let(:t) { Time.zone.local(2026, 3, 1, 12, 0, 0) }

  describe '.total_invested_breakdown' do
    it 'returns deposits plus referral minus reversals; withdrawals do not reduce total_invested' do
      Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0)
      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 1000.0,
        previous_balance: 0, new_balance: 1000.0, status: 'COMPLETED', date: t,
      )
      PortfolioHistory.create!(
        investor: investor, event: 'REFERRAL_COMMISSION', amount: 50.0,
        previous_balance: 1000.0, new_balance: 1050.0, status: 'COMPLETED', date: t + 1.hour,
      )
      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT_REVERSAL', amount: 100.0,
        previous_balance: 1050.0, new_balance: 950.0, status: 'COMPLETED', date: t + 2.hours,
      )
      PortfolioHistory.create!(
        investor: investor, event: 'WITHDRAWAL', amount: 200.0,
        previous_balance: 950.0, new_balance: 750.0, status: 'COMPLETED', date: t + 3.hours,
      )

      b = described_class.total_invested_breakdown(investor.id)
      expect(b[:deposits_sum]).to eq(BigDecimal('1000'))
      expect(b[:referral_sum]).to eq(BigDecimal('50'))
      expect(b[:deposit_reversals_sum]).to eq(BigDecimal('100'))
      expect(b[:withdrawals_sum]).to eq(BigDecimal('200'))
      expect(b[:total_invested]).to eq(BigDecimal('950'))
    end

    it 'does not reduce total_invested when withdrawals exceed prior deposits (retiro con ganancia)' do
      Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0)
      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 100.0,
        previous_balance: 0, new_balance: 100.0, status: 'COMPLETED', date: t,
      )
      PortfolioHistory.create!(
        investor: investor, event: 'WITHDRAWAL', amount: 500.0,
        previous_balance: 100.0, new_balance: 0.0, status: 'COMPLETED', date: t + 1.hour,
      )

      b = described_class.total_invested_breakdown(investor.id)
      expect(b[:total_invested]).to eq(BigDecimal('100'))
    end

    it 'ignores non-COMPLETED rows' do
      Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0)
      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 999.0,
        previous_balance: 0, new_balance: 999.0, status: 'PENDING', date: t,
      )

      b = described_class.total_invested_breakdown(investor.id)
      expect(b[:total_invested]).to eq(BigDecimal('0'))
    end
  end

  describe '.negative_total_invested_blocking_message' do
    it 'returns nil when all investors have non-negative implied total_invested' do
      Portfolio.create!(investor: investor, current_balance: 100, total_invested: 100)
      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: 100.0,
        previous_balance: 0, new_balance: 100.0, status: 'COMPLETED', date: t,
      )

      expect(described_class.negative_total_invested_blocking_message([investor])).to be_nil
    end

  end
end
