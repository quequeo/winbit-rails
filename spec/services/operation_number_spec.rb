# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OperationNumber do
  let(:investor) { Investor.create!(email: 'opnum@test.com', name: 'Op Num', status: 'ACTIVE') }
  let(:zone) { described_class::ZONE }

  def approved(type, at, investor_record = investor)
    InvestorRequest.create!(investor: investor_record, request_type: type, method: 'USDT', amount: 100,
                            status: 'APPROVED', processed_at: at, network: 'TRC20', wallet_address: 'TX')
  end

  it 'numbers the first deposit as A, later deposits as I and withdrawals as R' do
    first = approved('DEPOSIT', zone.local(2026, 10, 1, 19))
    second = approved('DEPOSIT', zone.local(2026, 10, 5, 19))
    withdrawal = approved('WITHDRAWAL', zone.local(2026, 10, 6, 19))

    expect(described_class.assign!(first)).to eq('A-2026-0001')
    expect(described_class.assign!(second)).to eq('I-2026-0001')
    expect(described_class.assign!(withdrawal)).to eq('R-2026-0001')
  end

  it 'keeps a correlative sequence per prefix and year' do
    other = Investor.create!(email: 'opnum2@test.com', name: 'Other', status: 'ACTIVE')
    described_class.assign!(approved('DEPOSIT', zone.local(2026, 10, 1, 19)))
    described_class.assign!(approved('DEPOSIT', zone.local(2026, 10, 2, 19), other))
    next_year = approved('WITHDRAWAL', zone.local(2027, 1, 2, 19))

    expect(InvestorRequest.pluck(:operation_number).compact).to contain_exactly('A-2026-0001', 'A-2026-0002')
    expect(described_class.assign!(next_year)).to eq('R-2027-0001')
  end

  it 'does not renumber a request that already has a number' do
    req = approved('DEPOSIT', zone.local(2026, 10, 1, 19))
    req.update_columns(operation_number: 'A-2026-0042')

    expect(described_class.assign!(req)).to eq('A-2026-0042')
  end

  describe 'integration with approval' do
    let(:admin) { User.create!(email: 'opnum-admin@test.com', name: 'Admin', role: 'ADMIN') }

    before { Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0) }

    it 'assigns the number on approval, tags the history row and clears it when the approval is undone' do
      req = InvestorRequest.create!(investor: investor, request_type: 'DEPOSIT', method: 'USDT', amount: 500, status: 'PENDING')

      Requests::Approve.new(request_id: req.id, approved_by: admin).call

      number = req.reload.operation_number
      expect(number).to match(/\AA-\d{4}-0001\z/)
      expect(PortfolioHistory.where(investor_id: investor.id, event: 'DEPOSIT').pluck(:operation_number)).to eq([ number ])

      Requests::ResetApprovedRequestToPending.new(request_id: req.id).call
      expect(req.reload.operation_number).to be_nil
    end
  end
end
