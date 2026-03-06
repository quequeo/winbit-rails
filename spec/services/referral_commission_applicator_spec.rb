# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReferralCommissionApplicator do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  describe '#apply' do
    it 'applies commission when investor has no future history' do
      inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')
      Portfolio.create!(investor: inv, current_balance: 100, total_invested: 100)

      applicator = described_class.new(inv, amount: 50, applied_by: admin)

      expect(applicator.apply).to be true
      expect(inv.portfolio.reload.current_balance).to eq(150)
      expect(PortfolioHistory.where(investor: inv, event: 'REFERRAL_COMMISSION').count).to eq(1)
    end

    it 'applies commission with backfill when there is future history' do
      inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')
      Portfolio.create!(investor: inv, current_balance: 200, total_invested: 100)

      PortfolioHistory.create!(
        investor: inv,
        event: 'DEPOSIT',
        amount: 100,
        previous_balance: 0,
        new_balance: 100,
        status: 'COMPLETED',
        date: 1.week.ago
      )
      PortfolioHistory.create!(
        investor: inv,
        event: 'OPERATING_RESULT',
        amount: 100,
        previous_balance: 100,
        new_balance: 200,
        status: 'COMPLETED',
        date: 1.day.ago
      )

      applicator = described_class.new(inv, amount: 50, applied_by: admin, applied_at: 2.days.ago)

      expect(applicator.apply).to be true
      expect(inv.portfolio.reload.current_balance).to eq(250)
    end

    it 'fails when investor is blank' do
      applicator = described_class.new(nil, amount: 50, applied_by: admin)

      expect(applicator.apply).to be false
      expect(applicator.errors).to include('Investor is required')
    end

    it 'fails when investor is inactive' do
      inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'INACTIVE')

      applicator = described_class.new(inv, amount: 50, applied_by: admin)

      expect(applicator.apply).to be false
      expect(applicator.errors).to include('Investor must be active')
    end

    it 'fails when applied_by is blank' do
      inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')

      applicator = described_class.new(inv, amount: 50, applied_by: nil)

      expect(applicator.apply).to be false
      expect(applicator.errors).to include('Applied by user is required')
    end

    it 'fails when amount is zero or negative' do
      inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')

      applicator = described_class.new(inv, amount: 0, applied_by: admin)
      expect(applicator.apply).to be false
      expect(applicator.errors).to include('Amount must be greater than 0')

      applicator2 = described_class.new(inv, amount: -10, applied_by: admin)
      expect(applicator2.apply).to be false
      expect(applicator2.errors).to include('Amount must be greater than 0')
    end

    it 'fails when amount is invalid' do
      inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')

      applicator = described_class.new(inv, amount: 'not-a-number', applied_by: admin)

      expect(applicator.apply).to be false
      expect(applicator.errors).to include('Amount is invalid')
    end

    it 'accepts applied_at as YYYY-MM-DD string' do
      inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')
      Portfolio.create!(investor: inv, current_balance: 100, total_invested: 100)

      applicator = described_class.new(inv, amount: 25, applied_by: admin, applied_at: '2025-01-15')

      expect(applicator.apply).to be true
      ph = PortfolioHistory.where(investor: inv, event: 'REFERRAL_COMMISSION').last
      expect(ph.date.to_date).to eq(Date.new(2025, 1, 15))
    end
  end
end
