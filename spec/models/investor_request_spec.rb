require 'rails_helper'

RSpec.describe InvestorRequest, type: :model do
  let(:investor) { Investor.create!(email: 'test@example.com', name: 'Test Investor', status: 'ACTIVE') }

  describe 'validations' do
    it 'is valid with valid attributes' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        status: 'PENDING',
        requested_at: Time.current
      )
      expect(request).to be_valid
    end

    it 'requires investor' do
      request = InvestorRequest.new(
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        status: 'PENDING'
      )
      expect(request).not_to be_valid
    end

    it 'requires request_type' do
      request = InvestorRequest.new(
        investor: investor,
        method: 'USDT',
        amount: 1000,
        status: 'PENDING'
      )
      expect(request).not_to be_valid
    end

    it 'requires method' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        amount: 1000,
        status: 'PENDING'
      )
      expect(request).not_to be_valid
    end

    it 'requires amount' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        status: 'PENDING'
      )
      expect(request).not_to be_valid
    end

    it 'validates amount is positive' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: -100,
        status: 'PENDING'
      )
      expect(request).not_to be_valid
    end

    it 'defaults status to PENDING' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000
      )
      expect(request.status).to eq('PENDING')
    end

    it 'defaults requested_at to current time' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000
      )
      expect(request.requested_at).to be_present
    end

    it 'allows optional network' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        network: 'TRC20',
        status: 'PENDING'
      )
      expect(request).to be_valid
    end

    it 'allows optional notes' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        notes: 'Some notes here',
        status: 'PENDING'
      )
      expect(request).to be_valid
    end

    it 'validates request_type is valid (database constraint)' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'INVALID',
        method: 'USDT',
        amount: 1000,
        status: 'PENDING'
      )
      expect { request.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'validates method is valid (database constraint)' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'INVALID',
        amount: 1000,
        status: 'PENDING'
      )
      expect { request.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'validates status is valid (database constraint)' do
      request = InvestorRequest.new(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        status: 'INVALID'
      )
      expect { request.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'associations' do
    it 'belongs to investor' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        status: 'PENDING'
      )
      expect(request.investor).to eq(investor)
    end
  end

  describe 'status changes' do
    let(:request) do
      InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000,
        status: 'PENDING'
      )
    end

    it 'can be approved' do
      request.update!(status: 'APPROVED', processed_at: Time.current)
      expect(request.status).to eq('APPROVED')
      expect(request.processed_at).to be_present
    end

    it 'can be rejected' do
      request.update!(status: 'REJECTED', processed_at: Time.current)
      expect(request.status).to eq('REJECTED')
      expect(request.processed_at).to be_present
    end
  end

  describe 'types' do
    it 'supports DEPOSIT type' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000
      )
      expect(request.request_type).to eq('DEPOSIT')
    end

    it 'supports WITHDRAWAL type' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'WITHDRAWAL',
        method: 'USDC',
        amount: 500
      )
      expect(request.request_type).to eq('WITHDRAWAL')
    end
  end

  describe 'methods' do
    it 'supports USDT' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDT',
        amount: 1000
      )
      expect(request.method).to eq('USDT')
    end

    it 'supports USDC' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'USDC',
        amount: 1000
      )
      expect(request.method).to eq('USDC')
    end

    it 'supports LEMON_CASH' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'LEMON_CASH',
        amount: 1000
      )
      expect(request.method).to eq('LEMON_CASH')
    end

    it 'supports CASH' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'CASH',
        amount: 1000
      )
      expect(request.method).to eq('CASH')
    end

    it 'supports SWIFT' do
      request = InvestorRequest.create!(
        investor: investor,
        request_type: 'DEPOSIT',
        method: 'SWIFT',
        amount: 1000
      )
      expect(request.method).to eq('SWIFT')
    end
  end
end
