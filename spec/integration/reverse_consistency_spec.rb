# frozen_string_literal: true

require 'rails_helper'

# Integration test: builds a rich scenario (deposits, withdrawals, operating results,
# withdrawal fees) and verifies that reverting a deposit or withdrawal leaves
# portfolio consistent (balance, total_invested match PortfolioRecalculator replay).
RSpec.describe 'Reverse consistency', type: :integration do
  # Use a fixed past date so operating results are not "future"
  let(:base_date) { 1.year.ago.to_date }

  def dt(d, hh = 19, mm = 0)
    Time.zone.local(d.year, d.month, d.day, hh, mm, 0)
  end

  let!(:admin) { User.create!(email: 'admin-reverse-cons@test.com', name: 'Admin', role: 'ADMIN') }
  let!(:investor) do
    Investor.create!(
      email: 'inv-reverse-cons@test.com',
      name: 'Investor',
      status: 'ACTIVE',
      trading_fee_percentage: 30
    )
  end

  before do
    Portfolio.create!(investor: investor, current_balance: 0, total_invested: 0)

    # Timeline: base_date + 0..8
    # d0: Deposit 1000
    # d1: Operating +1%
    # d2: Deposit 500
    # d3: Withdrawal 200 (fee from profit)
    # d4: Operating +0.5%
    # d5: Deposit 300
    # d6: Deposit 400
    # d7: Withdrawal 100 (fee from profit)
    # d8: Deposit 200

    d0 = base_date
    d1 = base_date + 1.day
    d2 = base_date + 2.days
    d3 = base_date + 3.days
    d4 = base_date + 4.days
    d5 = base_date + 5.days
    d6 = base_date + 6.days
    d7 = base_date + 7.days
    d8 = base_date + 8.days

    dep1_req = InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 1000,
      status: 'PENDING',
      requested_at: dt(d0)
    )
    Requests::Approve.new(request_id: dep1_req.id, processed_at: dt(d0), approved_by: admin).call

    DailyOperatingResultApplicator.new(date: d1, percent: 1.0, applied_by: admin).apply

    dep2_req = InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 500,
      status: 'PENDING',
      requested_at: dt(d2)
    )
    Requests::Approve.new(request_id: dep2_req.id, processed_at: dt(d2), approved_by: admin).call

    wd1_req = InvestorRequest.create!(
      investor: investor,
      request_type: 'WITHDRAWAL',
      method: 'USDC',
      amount: 200,
      status: 'PENDING',
      requested_at: dt(d3)
    )
    Requests::Approve.new(request_id: wd1_req.id, processed_at: dt(d3), approved_by: admin).call

    DailyOperatingResultApplicator.new(date: d4, percent: 0.5, applied_by: admin).apply

    dep3_req = InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 300,
      status: 'PENDING',
      requested_at: dt(d5)
    )
    Requests::Approve.new(request_id: dep3_req.id, processed_at: dt(d5), approved_by: admin).call

    dep4_req = InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 400,
      status: 'PENDING',
      requested_at: dt(d6)
    )
    Requests::Approve.new(request_id: dep4_req.id, processed_at: dt(d6), approved_by: admin).call

    wd2_req = InvestorRequest.create!(
      investor: investor,
      request_type: 'WITHDRAWAL',
      method: 'USDC',
      amount: 100,
      status: 'PENDING',
      requested_at: dt(d7)
    )
    Requests::Approve.new(request_id: wd2_req.id, processed_at: dt(d7), approved_by: admin).call

    dep5_req = InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      method: 'USDT',
      amount: 200,
      status: 'PENDING',
      requested_at: dt(d8)
    )
    Requests::Approve.new(request_id: dep5_req.id, processed_at: dt(d8), approved_by: admin).call

    @dep3_id = dep3_req.id
    @dep4_id = dep4_req.id
    @wd1_id = wd1_req.id
    @wd2_id = wd2_req.id
  end

  def expect_portfolio_consistent
    investor.reload
    portfolio = investor.portfolio
    PortfolioRecalculator.recalculate!(investor)
    portfolio.reload
    investor.reload

    deposits_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'DEPOSIT').sum(:amount)
    deposit_rev_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'DEPOSIT_REVERSAL').sum(:amount)
    withdrawals_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'WITHDRAWAL').sum(:amount)
    expected_total = deposits_sum - deposit_rev_sum - withdrawals_sum
    expect(portfolio.total_invested.to_f.round(2)).to eq(expected_total.to_f.round(2)),
      "total_invested=#{portfolio.total_invested} expected=#{expected_total} (deposits=#{deposits_sum} rev=#{deposit_rev_sum} wd=#{withdrawals_sum})"
  end

  it 'reverting deposit leaves portfolio consistent' do
    dep_req = InvestorRequest.find(@dep4_id)
    investor.reload
    balance_before = investor.portfolio.reload.current_balance.to_f
    total_before = investor.portfolio.total_invested.to_f

    Requests::ReverseApprovedDeposit.new(request_id: dep_req.id, reversed_by: admin).call

    dep_req.reload
    expect(dep_req.status).to eq('REVERSED')
    expect(dep_req.reversed_at).to be_present

    investor.reload
    portfolio = investor.portfolio.reload
    expect(portfolio.current_balance.to_f.round(2)).to eq((balance_before - 400).round(2))
    expect(portfolio.total_invested.to_f.round(2)).to eq((total_before - 400).round(2))

    expect_portfolio_consistent

    expect(PortfolioHistory.exists?(investor_id: investor.id, event: 'DEPOSIT_REVERSAL', amount: 400)).to be true
  end

  it 'reverting withdrawal leaves portfolio consistent' do
    wd_req = InvestorRequest.find(@wd1_id)
    fee = TradingFee.find_by(withdrawal_request_id: wd_req.id, source: 'WITHDRAWAL')
    fee_amount = fee&.fee_amount.to_f
    investor.reload
    balance_before = investor.portfolio.reload.current_balance.to_f
    total_before = investor.portfolio.total_invested.to_f

    Requests::ReverseApprovedWithdrawal.new(request_id: wd_req.id, reversed_by: admin).call

    wd_req.reload
    expect(wd_req.status).to eq('REVERSED')

    investor.reload
    portfolio = investor.portfolio
    expect(portfolio.current_balance.to_f).to eq((balance_before + 200 + fee_amount).round(2))
    expect(portfolio.total_invested.to_f).to eq((total_before + 200).round(2))

    expect_portfolio_consistent

    fee.reload
    expect(fee.voided_at).to be_present
  end

  it 'reverting multiple operations keeps consistency' do
    # First revert deposit 4 (400)
    Requests::ReverseApprovedDeposit.new(request_id: @dep4_id, reversed_by: admin).call
    expect_portfolio_consistent

    # Then revert withdrawal 1
    Requests::ReverseApprovedWithdrawal.new(request_id: @wd1_id, reversed_by: admin).call
    expect_portfolio_consistent

    # Then revert deposit 3 (300)
    Requests::ReverseApprovedDeposit.new(request_id: @dep3_id, reversed_by: admin).call
    expect_portfolio_consistent
  end
end
