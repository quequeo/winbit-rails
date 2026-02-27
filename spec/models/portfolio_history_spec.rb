require 'rails_helper'

RSpec.describe PortfolioHistory, type: :model do
  let(:investor) { Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE') }

  describe 'constants' do
    it 'defines valid EVENTS' do
      expect(PortfolioHistory::EVENTS).to eq(%w[DEPOSIT WITHDRAWAL DEPOSIT_REVERSAL OPERATING_RESULT TRADING_FEE TRADING_FEE_ADJUSTMENT REFERRAL_COMMISSION])
    end

    it 'defines valid STATUSES' do
      expect(PortfolioHistory::STATUSES).to eq(%w[PENDING COMPLETED REJECTED])
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000,
        status: 'COMPLETED',
        date: Time.current
      )
      expect(history).to be_valid
    end

    it 'validates event inclusion' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'INVALID_EVENT',
        amount: 1000,
        status: 'COMPLETED'
      )
      expect(history).not_to be_valid
      expect(history.errors[:event]).to include('is not included in the list')
    end

    it 'validates status inclusion' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        status: 'INVALID_STATUS'
      )
      expect(history).not_to be_valid
      expect(history.errors[:status]).to include('is not included in the list')
    end

    it 'requires investor' do
      history = PortfolioHistory.new(
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000
      )
      expect(history).not_to be_valid
    end

    it 'requires event' do
      history = PortfolioHistory.new(
        investor: investor,
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000
      )
      expect(history).not_to be_valid
    end

    it 'defaults status to COMPLETED' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000
      )
      expect(history.status).to eq('COMPLETED')
    end

    it 'defaults date to current timestamp' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000
      )
      expect(history.date).to be_present
    end

    it 'defaults monetary values to 0' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT'
      )
      expect(history.amount).to eq(0)
      expect(history.previous_balance).to eq(0)
      expect(history.new_balance).to eq(0)
    end
  end

  describe 'associations' do
    it 'belongs to investor' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000
      )
      expect(history.investor).to eq(investor)
    end
  end

  describe 'event types' do
    it 'accepts DEPOSIT event' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000
      )
      expect(history.event).to eq('DEPOSIT')
    end

    it 'accepts WITHDRAWAL event' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'WITHDRAWAL',
        amount: 500,
        previous_balance: 5000,
        new_balance: 4500
      )
      expect(history.event).to eq('WITHDRAWAL')
    end

    it 'accepts OPERATING_RESULT event' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: 200,
        previous_balance: 5000,
        new_balance: 5200
      )
      expect(history.event).to eq('OPERATING_RESULT')
    end

    it 'accepts TRADING_FEE event' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'TRADING_FEE',
        amount: -50,
        previous_balance: 5000,
        new_balance: 4950
      )
      expect(history.event).to eq('TRADING_FEE')
    end

    it 'accepts TRADING_FEE_ADJUSTMENT event' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'TRADING_FEE_ADJUSTMENT',
        amount: 10,
        previous_balance: 4950,
        new_balance: 4960
      )
      expect(history.event).to eq('TRADING_FEE_ADJUSTMENT')
    end

    it 'accepts REFERRAL_COMMISSION event' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'REFERRAL_COMMISSION',
        amount: 100,
        previous_balance: 5000,
        new_balance: 5100
      )
      expect(history.event).to eq('REFERRAL_COMMISSION')
    end

    it 'rejects invalid events' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'DEPOSITO',
        amount: 1000
      )
      expect(history).not_to be_valid
    end
  end

  describe 'balance tracking' do
    it 'tracks balance changes correctly' do
      initial_balance = 5000
      deposit_amount = 1000
      final_balance = initial_balance + deposit_amount

      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: deposit_amount,
        previous_balance: initial_balance,
        new_balance: final_balance
      )

      expect(history.new_balance - history.previous_balance).to eq(deposit_amount)
    end

    it 'handles negative changes for withdrawals' do
      initial_balance = 5000
      withdrawal_amount = 1000
      final_balance = initial_balance - withdrawal_amount

      history = PortfolioHistory.create!(
        investor: investor,
        event: 'WITHDRAWAL',
        amount: withdrawal_amount,
        previous_balance: initial_balance,
        new_balance: final_balance
      )

      expect(history.previous_balance - history.new_balance).to eq(withdrawal_amount)
    end

    it 'rejects inconsistent balances for completed events' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 5800,
        status: 'COMPLETED'
      )

      expect(history).not_to be_valid
      expect(history.errors[:new_balance]).to include('must be consistent with previous_balance and amount')
    end

    it 'allows pending entries without strict balance consistency' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 5800,
        status: 'PENDING'
      )

      expect(history).to be_valid
    end

    it 'requires positive amount for WITHDRAWAL' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'WITHDRAWAL',
        amount: -100,
        previous_balance: 1000,
        new_balance: 1100,
        status: 'COMPLETED'
      )

      expect(history).not_to be_valid
      expect(history.errors[:amount]).to include('must be greater than 0 for WITHDRAWAL')
    end

    it 'requires negative amount for TRADING_FEE' do
      history = PortfolioHistory.new(
        investor: investor,
        event: 'TRADING_FEE',
        amount: 100,
        previous_balance: 1000,
        new_balance: 900,
        status: 'COMPLETED'
      )

      expect(history).not_to be_valid
      expect(history.errors[:amount]).to include('must be lower than 0 for TRADING_FEE')
    end
  end

  describe 'status states' do
    it 'supports COMPLETED status' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000,
        status: 'COMPLETED'
      )
      expect(history.status).to eq('COMPLETED')
    end

    it 'supports PENDING status' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000,
        status: 'PENDING'
      )
      expect(history.status).to eq('PENDING')
    end

    it 'supports REJECTED status' do
      history = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000,
        status: 'REJECTED'
      )
      expect(history.status).to eq('REJECTED')
    end
  end

  describe 'ordering' do
    it 'can be ordered by date' do
      history1 = PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 1000,
        previous_balance: 5000,
        new_balance: 6000,
        date: Time.current - 2.days
      )
      history2 = PortfolioHistory.create!(
        investor: investor,
        event: 'WITHDRAWAL',
        amount: 500,
        previous_balance: 6000,
        new_balance: 5500,
        date: Time.current - 1.day
      )

      histories = PortfolioHistory.where(investor: investor).order(date: :desc)
      expect(histories.first).to eq(history2)
      expect(histories.last).to eq(history1)
    end
  end

  describe 'total invested calculation' do
    it 'calculates deposits minus withdrawals' do
      PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 10_000,
        previous_balance: 0,
        new_balance: 10_000
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 5_000,
        previous_balance: 10_000,
        new_balance: 15_000
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'WITHDRAWAL',
        amount: 1_000,
        previous_balance: 15_000,
        new_balance: 14_000
      )

      deposits = investor.portfolio_histories.where(event: 'DEPOSIT').sum(:amount)
      withdrawals = investor.portfolio_histories.where(event: 'WITHDRAWAL').sum(:amount)
      total_invested = deposits - withdrawals

      expect(deposits).to eq(15_000)
      expect(withdrawals).to eq(1_000)
      expect(total_invested).to eq(14_000)
    end

    it 'does not count OPERATING_RESULT events in total invested' do
      PortfolioHistory.create!(
        investor: investor,
        event: 'DEPOSIT',
        amount: 10_000,
        previous_balance: 0,
        new_balance: 10_000
      )
      PortfolioHistory.create!(
        investor: investor,
        event: 'OPERATING_RESULT',
        amount: 500,
        previous_balance: 10_000,
        new_balance: 10_500
      )

      deposits = investor.portfolio_histories.where(event: 'DEPOSIT').sum(:amount)
      profits = investor.portfolio_histories.where(event: 'OPERATING_RESULT').sum(:amount)

      expect(deposits).to eq(10_000)
      expect(profits).to eq(500)
      expect(deposits).not_to eq(deposits + profits)
    end
  end
end
