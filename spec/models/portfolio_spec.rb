require 'rails_helper'

RSpec.describe Portfolio, type: :model do
  let(:investor) { Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE') }

  describe 'validations' do
    it 'is valid with valid attributes' do
      portfolio = Portfolio.new(
        investor: investor,
        current_balance: 1000,
        total_invested: 1000,
        accumulated_return_usd: 0,
        accumulated_return_percent: 0,
        annual_return_usd: 0,
        annual_return_percent: 0
      )
      expect(portfolio).to be_valid
    end

    it 'validates current_balance is not negative' do
      portfolio = Portfolio.new(investor: investor, current_balance: -100, total_invested: 0)
      expect(portfolio).not_to be_valid
    end

    it 'validates total_invested is not negative' do
      portfolio = Portfolio.new(investor: investor, current_balance: 0, total_invested: -100)
      expect(portfolio).not_to be_valid
    end

    it 'requires investor' do
      portfolio = Portfolio.new(current_balance: 1000, total_invested: 1000)
      expect(portfolio).not_to be_valid
    end

    it 'requires unique investor' do
      Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000)
      portfolio = Portfolio.new(investor: investor, current_balance: 2000, total_invested: 2000)
      expect(portfolio).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to investor' do
      portfolio = Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000)
      expect(portfolio.investor).to eq(investor)
    end
  end

  describe 'defaults' do
    it 'defaults all monetary fields to 0' do
      portfolio = Portfolio.create!(investor: investor)
      expect(portfolio.current_balance).to eq(0)
      expect(portfolio.total_invested).to eq(0)
      expect(portfolio.accumulated_return_usd).to eq(0)
      expect(portfolio.accumulated_return_percent).to eq(0)
      expect(portfolio.annual_return_usd).to eq(0)
      expect(portfolio.annual_return_percent).to eq(0)
    end
  end

  describe 'updates' do
    it 'can update balance' do
      portfolio = Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000)
      portfolio.update!(current_balance: 1500)
      expect(portfolio.reload.current_balance).to eq(1500)
    end

    it 'can update returns' do
      portfolio = Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000)
      portfolio.update!(
        accumulated_return_usd: 200,
        accumulated_return_percent: 20
      )
      expect(portfolio.reload.accumulated_return_usd).to eq(200)
      expect(portfolio.reload.accumulated_return_percent).to eq(20)
    end
  end
end
