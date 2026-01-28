#!/usr/bin/env ruby
# Demo seed (single investor): jaimegarciamendez@gmail.com
#
# This seed resets ONLY Jaime + global operating results and then loads a deterministic timeline:
# - Deposits/withdrawals are created as APPROVED InvestorRequest + completed PortfolioHistory
# - Operating results are applied via DailyOperatingResultApplicator (creates DailyOperatingResult + PortfolioHistory)
# - Trading fee Q4 2025 (30%) is applied via TradingFeeApplicator (creates TradingFee + PortfolioHistory)
#
# Run:
#   bin/rails runner db/seeds/demo_minimal_jaime_2026.rb

require 'bigdecimal'
require 'active_support/testing/time_helpers'
include ActiveSupport::Testing::TimeHelpers

def bd(n)
  BigDecimal(n.to_s)
end

def round2(x)
  bd(x).round(2, :half_up)
end

def tz_time(y, m, d, hh, mm = 0, ss = 0)
  Time.zone.local(y, m, d, hh, mm, ss)
end

def per_day_percent_for_total(total_return:, days:)
  # total_return is decimal (0.15 for +15%, -0.10 for -10%)
  base = 1.0 + total_return.to_f
  raise 'Invalid total_return (must be > -100%)' if base <= 0
  p = (base**(1.0 / days.to_f)) - 1.0
  (p * 100.0)
end

def apply_cash!(investor:, request_type:, amount:, requested_at:, processed_at:, method: 'USDT', network: 'TRC20', notes: 'seed-jaime')
  amt = bd(amount).round(2, :half_up)

  InvestorRequest.create!(
    investor: investor,
    request_type: request_type,
    amount: amt.to_f,
    method: method,
    network: network,
    status: 'APPROVED',
    requested_at: requested_at,
    processed_at: processed_at,
    notes: notes,
  )

  portfolio = investor.portfolio || investor.build_portfolio
  prev = bd(portfolio.current_balance)

  new_balance =
    if request_type == 'DEPOSIT'
      (prev + amt).round(2, :half_up)
    else
      raise 'Insufficient balance for withdrawal' if prev < amt
      (prev - amt).round(2, :half_up)
    end

  PortfolioHistory.create!(
    investor: investor,
    event: request_type,
    amount: amt.to_f,
    previous_balance: prev.to_f,
    new_balance: new_balance.to_f,
    status: 'COMPLETED',
    date: processed_at,
  )

  deposits_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'DEPOSIT').sum(:amount)
  withdrawals_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'WITHDRAWAL').sum(:amount)
  total_invested = (bd(deposits_sum) - bd(withdrawals_sum)).round(2, :half_up)

  acc_usd = (new_balance - total_invested).round(2, :half_up)
  acc_pct = total_invested.positive? ? ((acc_usd / total_invested) * 100).round(4, :half_up) : bd('0')

  portfolio.update!(
    current_balance: new_balance.to_f,
    total_invested: total_invested.to_f,
    accumulated_return_usd: acc_usd.to_f,
    accumulated_return_percent: acc_pct.to_f,
  )
end

def apply_operativas!(admin:, dates:, total_return:, notes: 'seed-jaime')
  per_day = per_day_percent_for_total(total_return: total_return, days: dates.length)
  dates.each do |d|
    applicator = DailyOperatingResultApplicator.new(date: d, percent: per_day, applied_by: admin, notes: notes)
    ok = applicator.apply
    raise "Failed operativa #{d}: #{applicator.errors.join(', ')}" unless ok
  end
end

admin = User.find_by!(email: 'jaimegarciamendez@gmail.com')

# Reset ONLY Jaime + global strategy records (operativas and trading fees)
ApplicationRecord.transaction do
  TradingFee.delete_all
  DailyOperatingResult.delete_all

  inv = Investor.find_by(email: 'jaimegarciamendez@gmail.com')
  if inv
    PortfolioHistory.where(investor_id: inv.id).delete_all
    InvestorRequest.where(investor_id: inv.id).delete_all
    Portfolio.where(investor_id: inv.id).delete_all
    inv.delete
  end
end

investor = Investor.create!(email: 'jaimegarciamendez@gmail.com', name: 'Jaime García', status: 'ACTIVE')
Portfolio.create!(
  investor: investor,
  current_balance: 0,
  total_invested: 0,
  accumulated_return_usd: 0,
  accumulated_return_percent: 0,
  annual_return_usd: 0,
  annual_return_percent: 0,
)

notes = 'seed-jaime-timeline'

# 2024-05-10 deposit 10,000
apply_cash!(
  investor: investor,
  request_type: 'DEPOSIT',
  amount: 10_000,
  requested_at: tz_time(2024, 5, 10, 10, 0, 0),
  processed_at: tz_time(2024, 5, 10, 19, 0, 0),
  notes: notes,
)

# May 2024 +15% split across 5 operating days (Mon-Fri after deposit day)
apply_operativas!(
  admin: admin,
  dates: [
    Date.new(2024, 5, 13),
    Date.new(2024, 5, 14),
    Date.new(2024, 5, 15),
    Date.new(2024, 5, 16),
    Date.new(2024, 5, 17),
  ],
  total_return: 0.15,
  notes: notes,
)

# 2024-07-10 deposit 3,000
apply_cash!(
  investor: investor,
  request_type: 'DEPOSIT',
  amount: 3_000,
  requested_at: tz_time(2024, 7, 10, 10, 0, 0),
  processed_at: tz_time(2024, 7, 10, 19, 0, 0),
  notes: notes,
)

# October 2024 +15% split across 2 days
apply_operativas!(
  admin: admin,
  dates: [
    Date.new(2024, 10, 10),
    Date.new(2024, 10, 11),
  ],
  total_return: 0.15,
  notes: notes,
)

# 2025-06-10 deposit 3,000
apply_cash!(
  investor: investor,
  request_type: 'DEPOSIT',
  amount: 3_000,
  requested_at: tz_time(2025, 6, 10, 10, 0, 0),
  processed_at: tz_time(2025, 6, 10, 19, 0, 0),
  notes: notes,
)

# October 2025 +15% split across 5 days
apply_operativas!(
  admin: admin,
  dates: [
    Date.new(2025, 10, 6),
    Date.new(2025, 10, 7),
    Date.new(2025, 10, 8),
    Date.new(2025, 10, 9),
    Date.new(2025, 10, 10),
  ],
  total_return: 0.15,
  notes: notes,
)

# 2025-11-05 deposit 5,000
apply_cash!(
  investor: investor,
  request_type: 'DEPOSIT',
  amount: 5_000,
  requested_at: tz_time(2025, 11, 5, 10, 0, 0),
  processed_at: tz_time(2025, 11, 5, 19, 0, 0),
  notes: notes,
)

# 2025-11-10 withdrawal 6,000
apply_cash!(
  investor: investor,
  request_type: 'WITHDRAWAL',
  amount: 6_000,
  requested_at: tz_time(2025, 11, 10, 10, 0, 0),
  processed_at: tz_time(2025, 11, 10, 19, 0, 0),
  notes: notes,
)

# November 2025 -10% split across 3 days (after withdrawal)
apply_operativas!(
  admin: admin,
  dates: [
    Date.new(2025, 11, 12),
    Date.new(2025, 11, 13),
    Date.new(2025, 11, 14),
  ],
  total_return: -0.10,
  notes: notes,
)

# Deposit 4,000 in December 2025 (picked 2025-12-02)
apply_cash!(
  investor: investor,
  request_type: 'DEPOSIT',
  amount: 4_000,
  requested_at: tz_time(2025, 12, 2, 10, 0, 0),
  processed_at: tz_time(2025, 12, 2, 19, 0, 0),
  notes: notes,
)

# December 2025 +5% split across 4 days
apply_operativas!(
  admin: admin,
  dates: [
    Date.new(2025, 12, 3),
    Date.new(2025, 12, 4),
    Date.new(2025, 12, 5),
    Date.new(2025, 12, 8),
  ],
  total_return: 0.05,
  notes: notes,
)

# Trading fee Q4 2025 30% (period 2025-10-01..2025-12-31)
travel_to(tz_time(2026, 1, 2, 18, 0, 0)) do
  tf = TradingFeeApplicator.new(
    investor,
    fee_percentage: 30,
    applied_by: admin,
    notes: notes,
    period_start: Date.new(2025, 10, 1),
    period_end: Date.new(2025, 12, 31),
  )
  ok = tf.apply
  raise "Failed trading fee Q4 2025: #{tf.errors.join(', ')}" unless ok
end

# 2026-01-10 deposit 3,000
apply_cash!(
  investor: investor,
  request_type: 'DEPOSIT',
  amount: 3_000,
  requested_at: tz_time(2026, 1, 10, 10, 0, 0),
  processed_at: tz_time(2026, 1, 10, 19, 0, 0),
  notes: notes,
)

# 2026-01-15 withdrawal 2,000
apply_cash!(
  investor: investor,
  request_type: 'WITHDRAWAL',
  amount: 2_000,
  requested_at: tz_time(2026, 1, 15, 10, 0, 0),
  processed_at: tz_time(2026, 1, 15, 19, 0, 0),
  notes: notes,
)

# January 2026 +10% (a la fecha) split across 2 days
apply_operativas!(
  admin: admin,
  dates: [
    Date.new(2026, 1, 20),
    Date.new(2026, 1, 21),
  ],
  total_return: 0.10,
  notes: notes,
)

# Final consistency pass: recompute balances + portfolio snapshot from completed histories (important for backfills)
investor.reload
portfolio = investor.portfolio

histories = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED').order(:date, :created_at)
running = BigDecimal('0')
histories.each do |h|
  prev = running
  amt = BigDecimal(h.amount.to_s)
  delta = case h.event
  when 'WITHDRAWAL' then -amt.abs
  when 'TRADING_FEE' then -amt.abs
  else amt
  end
  running = (running + delta).round(2, :half_up)
  h.update!(previous_balance: prev.to_f, new_balance: running.to_f)
end

deposits_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'DEPOSIT').sum(:amount)
withdrawals_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'WITHDRAWAL').sum(:amount)
total_invested = (BigDecimal(deposits_sum.to_s) - BigDecimal(withdrawals_sum.to_s)).round(2, :half_up)
acc_usd = (running - total_invested).round(2, :half_up)
acc_pct = total_invested.positive? ? ((acc_usd / total_invested) * 100).round(4, :half_up) : BigDecimal('0')

portfolio.update!(
  current_balance: running.to_f,
  total_invested: total_invested.to_f,
  accumulated_return_usd: acc_usd.to_f,
  accumulated_return_percent: acc_pct.to_f,
)

investor.reload
portfolio.reload

ytd_from = Time.zone.local(2026, 1, 1, 0, 0, 0)
ytd = TimeWeightedReturnCalculator.for_investor(investor_id: investor.id, from: ytd_from, to: Time.zone.local(2026, 1, 31, 23, 59, 59))
all_time = TimeWeightedReturnCalculator.for_investor(investor_id: investor.id, from: nil, to: Time.zone.local(2026, 1, 31, 23, 59, 59))

puts "\n=== Seed OK: Jaime timeline ==="
puts "investor=#{investor.email}"
puts "total_invested=#{round2(portfolio.total_invested).to_f}"
puts "current_balance=#{round2(portfolio.current_balance).to_f}"
puts "acc_return_usd=#{round2(portfolio.accumulated_return_usd).to_f}"
puts "acc_return_pct(legacy)=%#{bd(portfolio.accumulated_return_percent).round(4, :half_up).to_f}"
puts "TWR YTD 2026: #{ytd.twr_percent.round(4)}% (PnL $#{ytd.pnl_usd}) from=#{ytd.effective_start_at&.to_date}"
puts "TWR ALL: #{all_time.twr_percent.round(4)}% (PnL $#{all_time.pnl_usd}) from=#{all_time.effective_start_at&.to_date}"
puts "counts: requests=#{InvestorRequest.where(investor_id: investor.id).count} histories=#{PortfolioHistory.where(investor_id: investor.id).count} daily_operating_results=#{DailyOperatingResult.count} trading_fees=#{TradingFee.count}"
