require 'rails_helper'

RSpec.describe Investor, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      investor = Investor.new(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE')
      expect(investor).to be_valid
    end

    it 'requires email' do
      investor = Investor.new(name: 'Test Investor', status: 'ACTIVE')
      expect(investor).not_to be_valid
      expect(investor.errors[:email]).to be_present
    end

    it 'requires name' do
      investor = Investor.new(email: 'test@example.com', status: 'ACTIVE')
      expect(investor).not_to be_valid
      expect(investor.errors[:name]).to be_present
    end

    it 'requires unique email' do
      Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE')
      investor = Investor.new(email: 'test@example.com', name: 'Another Investor', status: 'ACTIVE')
      expect(investor).not_to be_valid
      expect(investor.errors[:email]).to include('has already been taken')
    end

    it 'defaults to ACTIVE status' do
      investor = Investor.create!(email: 'test@example.com', name: 'Test Investor')
      expect(investor.status).to eq('ACTIVE')
    end
  end

  describe 'associations' do
    it 'has one portfolio' do
      investor = Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE')
      portfolio = Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000)

      expect(investor.portfolio).to eq(portfolio)
    end

    it 'has many investor_requests' do
      investor = Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE')
      request1 = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        status: 'PENDING',
        requested_at: Time.current
      )
      request2 = InvestorRequest.create!(
        investor: investor,
        request_type: 'WITHDRAWAL',
        method: 'USDC',
        amount: 500,
        status: 'APPROVED',
        requested_at: Time.current
      )

      expect(investor.investor_requests).to include(request1, request2)
      expect(investor.investor_requests.count).to eq(2)
    end

    it 'destroys dependent records when destroyed' do
      investor = Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE')
      Portfolio.create!(investor: investor, current_balance: 1000, total_invested: 1000)
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        status: 'PENDING',
        requested_at: Time.current
      )

      expect { investor.destroy! }.to change(Portfolio, :count).by(-1)
        .and change(InvestorRequest, :count).by(-1)
    end
  end

  describe 'scopes or class methods' do
    it 'can query active investors' do
      active = Investor.create!(email: 'active@test.com', name: 'Active', status: 'ACTIVE')
      Investor.create!(email: 'inactive@test.com', name: 'Inactive', status: 'INACTIVE')

      actives = Investor.where(status: 'ACTIVE')
      expect(actives).to include(active)
      expect(actives.count).to eq(1)
    end
  end

  describe 'status methods' do
    it '#status_active? returns true for ACTIVE investors' do
      investor = Investor.create!(email: 'active@test.com', name: 'Active', status: 'ACTIVE')
      expect(investor.status_active?).to be true
    end

    it '#status_active? returns false for INACTIVE investors' do
      investor = Investor.create!(email: 'inactive@test.com', name: 'Inactive', status: 'INACTIVE')
      expect(investor.status_active?).to be false
    end

    it '#status_inactive? returns true for INACTIVE investors' do
      investor = Investor.create!(email: 'inactive@test.com', name: 'Inactive', status: 'INACTIVE')
      expect(investor.status_inactive?).to be true
    end

    it '#status_inactive? returns false for ACTIVE investors' do
      investor = Investor.create!(email: 'active@test.com', name: 'Active', status: 'ACTIVE')
      expect(investor.status_inactive?).to be false
    end
  end

  describe 'edge cases' do
    it 'handles very long names' do
      long_name = 'A' * 255
      investor = Investor.create!(email: 'long@test.com', name: long_name, status: 'ACTIVE')
      expect(investor.name.length).to eq(255)
    end

    it 'handles special characters in name' do
      investor = Investor.create!(email: 'special@test.com', name: 'José María Ñ', status: 'ACTIVE')
      expect(investor.name).to eq('José María Ñ')
    end

    it 'trims whitespace in email validation' do
      investor = Investor.create!(email: 'test@example.com', name: 'Test', status: 'ACTIVE')
      expect(investor.email).to eq('test@example.com')
    end
  end
end
