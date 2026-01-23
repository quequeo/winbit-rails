# Demo seed: 2 investors (jaimegarciamendez@gmail.com / amegarciamendez@gmail.com)
# Includes: deposits, withdrawals, daily operating results (months positive + negative), and trading fees.
# IMPORTANT: Trading Fees for Q4 2025 are intentionally NOT applied.
#
# Run:
#   bin/rails runner db/seeds/demo_jaime_amegar_2025.rb

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

def ensure_admin!(email, name: 'Admin', role: 'ADMIN')
  u = User.find_or_initialize_by(email: email)
  u.name = name
  u.role = role
  # provider/uid are set on first Google login (User.from_google_omniauth)
  u.provider = nil
  u.uid = nil
  u.save!
  u
end

def ensure_investor!(email, name)
  inv = Investor.find_or_initialize_by(email: email)
  inv.name = name
  inv.status = 'ACTIVE'
  inv.save!
  inv.portfolio || Portfolio.create!(investor: inv, current_balance: 0, total_invested: 0, accumulated_return_usd: 0, accumulated_return_percent: 0)
  inv
end

def apply_cash_movement!(investor:, request_type:, amount:, requested_at:, processed_at:, method: 'USDT')
  req = InvestorRequest.create!(
    investor: investor,
    request_type: request_type,
    method: method,
    amount: amount,
    status: 'PENDING',
    requested_at: requested_at,
  )

  portfolio = investor.portfolio
  prev = bd(portfolio.current_balance)
  amt = bd(amount)

  new_balance = if request_type == 'DEPOSIT'
    prev + amt
  else
    raise 'Balance insuficiente para retiro' if prev < amt
    prev - amt
  end

  new_total_invested = if request_type == 'DEPOSIT'
    bd(portfolio.total_invested) + amt
  else
    bd(portfolio.total_invested) - amt
  end

  req.update!(status: 'APPROVED', processed_at: processed_at)

  PortfolioHistory.create!(
    investor: investor,
    event: request_type,
    amount: amt.to_f,
    previous_balance: prev.to_f,
    new_balance: new_balance.to_f,
    status: 'COMPLETED',
    date: processed_at,
  )

  accumulated_return_usd = (new_balance - new_total_invested).round(2, :half_up)
  accumulated_return_percent = new_total_invested.positive? ? ((accumulated_return_usd / new_total_invested) * 100).round(4, :half_up) : bd('0')

  portfolio.update!(
    current_balance: new_balance.to_f,
    total_invested: new_total_invested.to_f,
    accumulated_return_usd: accumulated_return_usd.to_f,
    accumulated_return_percent: accumulated_return_percent.to_f,
  )

  req
end

def apply_month_operativa!(admin:, month_start:, month_end:, weekday_percent:)
  d = month_start
  while d <= month_end
    unless d.saturday? || d.sunday?
      DailyOperatingResultApplicator.new(
        date: d,
        percent: weekday_percent,
        applied_by: admin,
        notes: 'seed-demo',
      ).apply || raise("Failed operativa #{d}")
    end
    d += 1.day
  end
end

# --- Reset data (keep schema) ---
ApplicationRecord.transaction do
  TradingFee.delete_all
  DailyOperatingResult.delete_all
  PortfolioHistory.delete_all
  Portfolio.delete_all
  InvestorRequest.delete_all
  Investor.delete_all
end

# Admins habilitados para login (Google OAuth)
ensure_admin!('jaimegarciamendez@gmail.com', name: 'Jaime', role: 'SUPERADMIN')
ensure_admin!('winbit.cfds@gmail.com', name: 'Winbit', role: 'SUPERADMIN')
admin = User.find_by!(email: 'jaimegarciamendez@gmail.com')

jaime = ensure_investor!('jaimegarciamendez@gmail.com', 'Jaime')
amegar = ensure_investor!('amegarciamendez@gmail.com', 'Ame')

# --- Cash movements (deposits/withdrawals) ---
apply_cash_movement!(
  investor: jaime,
  request_type: 'DEPOSIT',
  amount: 10_000,
  requested_at: tz_time(2025, 1, 2, 10, 0),
  processed_at: tz_time(2025, 1, 2, 19, 0),
)
apply_cash_movement!(
  investor: amegar,
  request_type: 'DEPOSIT',
  amount: 6_000,
  requested_at: tz_time(2025, 1, 2, 10, 5),
  processed_at: tz_time(2025, 1, 2, 19, 5),
)

apply_cash_movement!(
  investor: jaime,
  request_type: 'DEPOSIT',
  amount: 2_000,
  requested_at: tz_time(2025, 6, 10, 11, 0),
  processed_at: tz_time(2025, 6, 10, 19, 0),
)
apply_cash_movement!(
  investor: amegar,
  request_type: 'WITHDRAWAL',
  amount: 500,
  requested_at: tz_time(2025, 8, 5, 11, 0),
  processed_at: tz_time(2025, 8, 5, 19, 0),
)

apply_cash_movement!(
  investor: amegar,
  request_type: 'DEPOSIT',
  amount: 1_000,
  requested_at: tz_time(2025, 11, 20, 11, 0),
  processed_at: tz_time(2025, 11, 20, 19, 0),
)

# --- Daily operating results (2025) ---
# Months with negative performance are included (Feb/May/Aug/Oct), but target ~22% annual (approx) overall.
monthly = {
  [2025, 1] => 0.10,   # ~ +2.2%
  [2025, 2] => -0.04,  # ~ -0.9%
  [2025, 3] => 0.21,   # ~ +4.6%
  [2025, 4] => 0.10,   # ~ +2.2%
  [2025, 5] => -0.04,  # ~ -0.9%
  [2025, 6] => 0.25,   # ~ +5.6%
  [2025, 7] => 0.10,   # ~ +2.2%
  [2025, 8] => -0.08,  # ~ -1.7%
  [2025, 9] => 0.26,   # ~ +5.9%
  [2025, 10] => -0.06, # ~ -1.3%
  [2025, 11] => 0.15,  # ~ +3.4%
  [2025, 12] => 0.23,  # ~ +5.2%
}

monthly.each do |(y, m), pct|
  ms = Date.new(y, m, 1)
  me = ms.end_of_month
  apply_month_operativa!(admin: admin, month_start: ms, month_end: me, weekday_percent: pct)
end

# --- Apply Trading Fees (NOT Q4 2025) ---
q2_start = Date.new(2025, 4, 1)
q2_end = Date.new(2025, 6, 30)
q3_start = Date.new(2025, 7, 1)
q3_end = Date.new(2025, 9, 30)
q4_start = Date.new(2025, 10, 1)
q4_end = Date.new(2025, 12, 31)

# Apply Q2 fees on Jul 1, 2025
travel_to(tz_time(2025, 7, 1, 18, 0)) do
  TradingFeeApplicator.new(jaime, fee_percentage: 25, applied_by: admin, notes: 'seed-demo Q2', period_start: q2_start, period_end: q2_end).apply
  TradingFeeApplicator.new(amegar, fee_percentage: 20, applied_by: admin, notes: 'seed-demo Q2', period_start: q2_start, period_end: q2_end).apply
end

# Apply Q3 fees on Oct 1, 2025
travel_to(tz_time(2025, 10, 1, 18, 0)) do
  TradingFeeApplicator.new(jaime, fee_percentage: 21, applied_by: admin, notes: 'seed-demo Q3', period_start: q3_start, period_end: q3_end).apply
  TradingFeeApplicator.new(amegar, fee_percentage: 30, applied_by: admin, notes: 'seed-demo Q3', period_start: q3_start, period_end: q3_end).apply
end

# Sanity: ensure Q4 fee NOT applied
raise 'Seed error: Q4 2025 TradingFee was applied but should NOT be.' if TradingFee.where(period_start: q4_start, period_end: q4_end).exists?

# Final consistency pass: recompute portfolio balances from PortfolioHistory (important if you backfill)
Investor.includes(:portfolio).find_each do |inv|
  portfolio = inv.portfolio || Portfolio.create!(investor: inv)
  histories = PortfolioHistory.where(investor_id: inv.id, status: 'COMPLETED').order(:date, :created_at)

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

  deposits_sum = PortfolioHistory.where(investor_id: inv.id, status: 'COMPLETED', event: 'DEPOSIT').sum(:amount)
  withdrawals_sum = PortfolioHistory.where(investor_id: inv.id, status: 'COMPLETED', event: 'WITHDRAWAL').sum(:amount)
  total_invested = (BigDecimal(deposits_sum.to_s) - BigDecimal(withdrawals_sum.to_s)).round(2, :half_up)

  acc_usd = (running - total_invested).round(2, :half_up)
  acc_pct = total_invested.positive? ? ((acc_usd / total_invested) * 100).round(4, :half_up) : BigDecimal('0')

  portfolio.update!(
    current_balance: running.to_f,
    total_invested: total_invested.to_f,
    accumulated_return_usd: acc_usd.to_f,
    accumulated_return_percent: acc_pct.to_f,
  )
end

# Print summary
[jaime, amegar].each do |inv|
  inv.reload
  p = inv.portfolio
  puts "\n=== #{inv.email} ==="
  puts "total_invested=#{round2(p.total_invested).to_f}"
  puts "current_balance=#{round2(p.current_balance).to_f}"
  ret = round2(bd(p.current_balance) - bd(p.total_invested))
  pct = bd(p.total_invested).positive? ? ((ret / bd(p.total_invested)) * 100).round(2, :half_up) : bd('0')
  puts "acc_return_usd=#{ret.to_f}"
  puts "acc_return_pct=#{pct.to_f}%"
end

puts "\nSeed OK: investors=#{Investor.count} requests=#{InvestorRequest.count} daily_operating_results=#{DailyOperatingResult.count} trading_fees=#{TradingFee.count}"
puts "Reminder: Q4 2025 Trading Fees are intentionally NOT applied."
