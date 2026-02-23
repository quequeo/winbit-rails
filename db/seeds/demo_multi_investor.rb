# db/seeds/demo_multi_investor.rb
#
# Demo seed: 10 investors with realistic data from June 2024 to Feb 2026.
# Covers deposits, withdrawals, referral commissions, daily operating results,
# and trading fees for QUARTERLY, MONTHLY, SEMESTRAL and ANNUAL frequencies.
#
# Run standalone:
#   bin/rails runner db/seeds/demo_multi_investor.rb
#
# Or add SEED_MULTI=true to seeds.rb and run: bin/rails db:seed

require 'bigdecimal'
require 'active_support/testing/time_helpers'
include ActiveSupport::Testing::TimeHelpers

puts "\n🌱 Multi-investor demo seed starting..."

# ── Helpers ──────────────────────────────────────────────────────────────────

def tz_time(y, m, d, hh = 18, mm = 0, ss = 0)
  Time.zone.local(y, m, d, hh, mm, ss)
end

def apply_cash!(investor:, request_type:, amount:, date:)
  investor.reload
  amt = BigDecimal(amount.to_s).round(2, :half_up)

  InvestorRequest.create!(
    investor:     investor,
    request_type: request_type,
    amount:       amt.to_f,
    method:       'USDT',
    network:      'TRC20',
    status:       'APPROVED',
    requested_at: tz_time(date.year, date.month, date.day, 10),
    processed_at: tz_time(date.year, date.month, date.day, 19),
    notes:        'seed-multi',
  )

  portfolio = investor.portfolio
  prev      = BigDecimal(portfolio.current_balance.to_s)
  new_bal   =
    if request_type == 'DEPOSIT'
      prev + amt
    else
      raise "Insufficient balance for withdrawal: #{investor.name} (#{prev} < #{amt})" if prev < amt
      prev - amt
    end

  PortfolioHistory.create!(
    investor:         investor,
    event:            request_type,
    amount:           amt.to_f,
    previous_balance: prev.to_f,
    new_balance:      new_bal.round(2, :half_up).to_f,
    status:           'COMPLETED',
    date:             tz_time(date.year, date.month, date.day, 19),
  )

  deps  = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'DEPOSIT').sum(:amount)
  wds   = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'WITHDRAWAL').sum(:amount)
  total = [BigDecimal(deps.to_s) - BigDecimal(wds.to_s), BigDecimal('0')].max
  acc   = new_bal - total

  portfolio.update!(
    current_balance:          new_bal.round(2, :half_up).to_f,
    total_invested:           total.round(2, :half_up).to_f,
    accumulated_return_usd:   acc.round(2, :half_up).to_f,
    accumulated_return_percent: total.positive? ? ((acc / total) * 100).round(4, :half_up).to_f : 0.0,
  )
end

def apply_referral!(investor:, amount:, date:)
  investor.reload
  portfolio = investor.portfolio
  prev      = BigDecimal(portfolio.current_balance.to_s)
  amt       = BigDecimal(amount.to_s).round(2, :half_up)
  new_bal   = prev + amt

  PortfolioHistory.create!(
    investor:         investor,
    event:            'REFERRAL_COMMISSION',
    amount:           amt.to_f,
    previous_balance: prev.to_f,
    new_balance:      new_bal.to_f,
    status:           'COMPLETED',
    date:             tz_time(date.year, date.month, date.day, 15),
  )

  portfolio.update!(current_balance: new_bal.to_f)
end

def apply_dor!(admin:, date:, pct:)
  app = DailyOperatingResultApplicator.new(
    date:       date,
    percent:    pct,
    applied_by: admin,
    notes:      'seed-multi',
  )
  ok = app.apply
  raise "DOR failed #{date} (#{pct}%): #{app.errors.join(', ')}" unless ok
end

def apply_trading_fee!(investor:, admin:, period_start:, period_end:, apply_date:)
  investor.reload
  return if investor.status != 'ACTIVE'

  travel_to(tz_time(apply_date.year, apply_date.month, apply_date.day, 18, 30)) do
    tf = TradingFeeApplicator.new(
      investor,
      fee_percentage: investor.trading_fee_percentage.to_f,
      applied_by:     admin,
      notes:          "seed-multi #{period_start} / #{period_end}",
      period_start:   period_start,
      period_end:     period_end,
    )
    ok = tf.apply
    unless ok
      puts "  ⚠  Fee skipped #{investor.name} #{period_start}→#{period_end}: #{tf.errors.join(', ')}"
    end
  end
end

# ── Clear existing data ───────────────────────────────────────────────────────

puts "Clearing existing data..."
ApplicationRecord.transaction do
  TradingFee.delete_all
  PortfolioHistory.delete_all
  Portfolio.delete_all
  InvestorRequest.delete_all
  DailyOperatingResult.delete_all
  Investor.delete_all
end

admin = User.order(created_at: :asc).first
raise 'No admin user found. Run: bin/rails db:seed first.' unless admin
puts "Using admin: #{admin.email}"

# ── Create investors ──────────────────────────────────────────────────────────

INVESTOR_PROFILES = [
  { key: :maria,     name: 'María García',     email: 'maria.garcia@seed.com',     frequency: 'QUARTERLY', pct: 30, start: Date.new(2024,  6, 1) },
  { key: :carlos,    name: 'Carlos López',     email: 'carlos.lopez@seed.com',     frequency: 'MONTHLY',   pct: 25, start: Date.new(2024,  7, 1) },
  { key: :ana,       name: 'Ana Martínez',     email: 'ana.martinez@seed.com',     frequency: 'SEMESTRAL', pct: 35, start: Date.new(2024,  6, 1) },
  { key: :roberto,   name: 'Roberto Silva',    email: 'roberto.silva@seed.com',    frequency: 'QUARTERLY', pct: 30, start: Date.new(2024,  8, 1) },
  { key: :laura,     name: 'Laura Fernández',  email: 'laura.fernandez@seed.com',  frequency: 'ANNUAL',    pct: 20, start: Date.new(2024,  6, 1) },
  { key: :diego,     name: 'Diego Torres',     email: 'diego.torres@seed.com',     frequency: 'MONTHLY',   pct: 25, start: Date.new(2024,  9, 1) },
  { key: :valentina, name: 'Valentina Ruiz',   email: 'valentina.ruiz@seed.com',   frequency: 'QUARTERLY', pct: 28, start: Date.new(2024, 10, 1) },
  { key: :matias,    name: 'Matías González',  email: 'matias.gonzalez@seed.com',  frequency: 'SEMESTRAL', pct: 28, start: Date.new(2024,  6, 1) },
  { key: :sofia,     name: 'Sofía Herrera',    email: 'sofia.herrera@seed.com',    frequency: 'ANNUAL',    pct: 22, start: Date.new(2024,  7, 1) },
  { key: :nicolas,   name: 'Nicolás Díaz',     email: 'nicolas.diaz@seed.com',     frequency: 'QUARTERLY', pct: 30, start: Date.new(2024,  6, 1) },
].freeze

investors = {}
INVESTOR_PROFILES.each do |p|
  inv = Investor.create!(
    name:                   p[:name],
    email:                  p[:email],
    password:               'Winbit2024!',
    trading_fee_frequency:  p[:frequency],
    trading_fee_percentage: p[:pct],
    status:                 'ACTIVE',
    created_at:             tz_time(p[:start].year, p[:start].month, p[:start].day, 9),
  )
  Portfolio.create!(
    investor:                  inv,
    current_balance:           0,
    total_invested:            0,
    accumulated_return_usd:    0,
    accumulated_return_percent: 0,
    annual_return_usd:         0,
    annual_return_percent:     0,
  )
  investors[p[:key]] = inv
  puts "  ✓ #{p[:name]} (#{p[:frequency]} #{p[:pct]}%)"
end

# ── DOR calendar (2-3 per month, Jun 2024 – Feb 2026) ────────────────────────

DOR_CALENDAR = [
  [2024,  6,  5,  0.85], [2024,  6, 12,  1.20], [2024,  6, 19, -0.45],
  [2024,  7,  3,  1.35], [2024,  7, 10,  0.95], [2024,  7, 24,  1.60],
  [2024,  8,  7, -0.30], [2024,  8, 14,  1.15], [2024,  8, 28,  0.70],
  [2024,  9,  4,  1.80], [2024,  9, 11, -0.55], [2024,  9, 25,  1.25],
  [2024, 10,  9,  0.90], [2024, 10, 16,  1.45], [2024, 10, 30, -0.40],
  [2024, 11,  6,  1.55], [2024, 11, 13,  0.85], [2024, 11, 27,  1.20],
  [2024, 12,  4,  2.10], [2024, 12, 11,  1.75], [2024, 12, 18, -0.65],
  [2025,  1,  8,  1.45], [2025,  1, 15, -0.35], [2025,  1, 29,  1.20],
  [2025,  2,  5,  0.95], [2025,  2, 12,  1.65], [2025,  2, 26,  0.80],
  [2025,  3,  5,  1.30], [2025,  3, 12, -0.50], [2025,  3, 19,  1.85],
  [2025,  4,  2,  0.75], [2025,  4,  9,  1.40], [2025,  4, 23,  1.10],
  [2025,  5,  7, -0.45], [2025,  5, 14,  1.60], [2025,  5, 21,  0.90],
  [2025,  6,  4,  1.25], [2025,  6, 11,  0.85], [2025,  6, 18,  1.50],
  [2025,  7,  2,  1.80], [2025,  7,  9, -0.30], [2025,  7, 23,  1.35],
  [2025,  8,  6,  0.95], [2025,  8, 13,  1.55], [2025,  8, 27, -0.60],
  [2025,  9,  3,  1.40], [2025,  9, 10,  1.20], [2025,  9, 17,  0.85],
  [2025, 10,  1, -0.25], [2025, 10,  8,  1.65], [2025, 10, 22,  1.10],
  [2025, 11,  5,  0.90], [2025, 11, 12,  1.35], [2025, 11, 26,  1.70],
  [2025, 12,  3,  1.50], [2025, 12, 10, -0.40], [2025, 12, 17,  2.20],
  [2026,  1,  7,  1.25], [2026,  1, 14,  0.85],
  [2026,  2,  4,  1.60], [2026,  2, 11, -0.30],
].freeze

# ── Build timeline ────────────────────────────────────────────────────────────
# Priority within same date: deposits first, then others, dor last.
# type priority: deposit=0, withdrawal=1, referral=2, deactivate=3, trading_fee=4, dor=5

TYPE_PRIORITY = { deposit: 0, withdrawal: 1, referral: 2, deactivate: 3, trading_fee: 4, dor: 5 }.freeze

timeline = []

# Initial deposits
{
  maria:     [Date.new(2024,  6, 1), 50_000],
  ana:       [Date.new(2024,  6, 1), 100_000],
  laura:     [Date.new(2024,  6, 1), 75_000],
  matias:    [Date.new(2024,  6, 1), 60_000],
  nicolas:   [Date.new(2024,  6, 1), 20_000],
  carlos:    [Date.new(2024,  7, 1), 25_000],
  sofia:     [Date.new(2024,  7, 1), 45_000],
  roberto:   [Date.new(2024,  8, 1), 30_000],
  diego:     [Date.new(2024,  9, 1), 15_000],
  valentina: [Date.new(2024, 10, 1), 40_000],
}.each do |key, (date, amount)|
  timeline << { type: :deposit, investor: key, date: date, amount: amount }
end

# Extra cash events
timeline << { type: :deposit,    investor: :maria,    date: Date.new(2024,  9,  3), amount: 10_000 }
timeline << { type: :withdrawal, investor: :carlos,   date: Date.new(2024, 12,  2), amount:  5_000 }
timeline << { type: :deposit,    investor: :ana,      date: Date.new(2025,  1,  3), amount: 20_000 }
timeline << { type: :deposit,    investor: :valentina, date: Date.new(2025,  2,  3), amount: 15_000 }
timeline << { type: :referral,   investor: :diego,    date: Date.new(2025,  3,  3), amount:    300 }
timeline << { type: :referral,   investor: :maria,    date: Date.new(2025,  6,  2), amount:    500 }
timeline << { type: :withdrawal, investor: :roberto,  date: Date.new(2025,  7,  2), amount:  5_000 }
timeline << { type: :withdrawal, investor: :sofia,    date: Date.new(2025, 10,  2), amount: 10_000 }

# DOR events
DOR_CALENDAR.each do |y, m, d, pct|
  timeline << { type: :dor, date: Date.new(y, m, d), pct: pct }
end

# QUARTERLY fees: María, Roberto, Nicolás (Q3 2024 – Q4 2025), Valentina (Q4 2024 – Q4 2025)
quarterly_schedule = [
  [:maria,    Date.new(2024,  7,  1), Date.new(2024,  9, 30)],
  [:maria,    Date.new(2024, 10,  1), Date.new(2024, 12, 31)],
  [:maria,    Date.new(2025,  1,  1), Date.new(2025,  3, 31)],
  [:maria,    Date.new(2025,  4,  1), Date.new(2025,  6, 30)],
  [:maria,    Date.new(2025,  7,  1), Date.new(2025,  9, 30)],
  [:maria,    Date.new(2025, 10,  1), Date.new(2025, 12, 31)],
  [:roberto,  Date.new(2024,  7,  1), Date.new(2024,  9, 30)],
  [:roberto,  Date.new(2024, 10,  1), Date.new(2024, 12, 31)],
  [:roberto,  Date.new(2025,  1,  1), Date.new(2025,  3, 31)],
  [:roberto,  Date.new(2025,  4,  1), Date.new(2025,  6, 30)],
  [:roberto,  Date.new(2025,  7,  1), Date.new(2025,  9, 30)],
  [:roberto,  Date.new(2025, 10,  1), Date.new(2025, 12, 31)],
  [:valentina, Date.new(2024, 10,  1), Date.new(2024, 12, 31)],
  [:valentina, Date.new(2025,  1,  1), Date.new(2025,  3, 31)],
  [:valentina, Date.new(2025,  4,  1), Date.new(2025,  6, 30)],
  [:valentina, Date.new(2025,  7,  1), Date.new(2025,  9, 30)],
  [:valentina, Date.new(2025, 10,  1), Date.new(2025, 12, 31)],
  [:nicolas,  Date.new(2024,  7,  1), Date.new(2024,  9, 30)],
  [:nicolas,  Date.new(2024, 10,  1), Date.new(2024, 12, 31)],
  [:nicolas,  Date.new(2025,  1,  1), Date.new(2025,  3, 31)],
  [:nicolas,  Date.new(2025,  4,  1), Date.new(2025,  6, 30)],
  [:nicolas,  Date.new(2025,  7,  1), Date.new(2025,  9, 30)],
]
quarterly_schedule.each do |key, ps, pe|
  timeline << { type: :trading_fee, investor: key, period_start: ps, period_end: pe, apply_date: pe }
end

# SEMESTRAL fees: Ana, Matías
[
  [:ana,    Date.new(2024,  7, 1), Date.new(2024, 12, 31)],
  [:ana,    Date.new(2025,  1, 1), Date.new(2025,  6, 30)],
  [:ana,    Date.new(2025,  7, 1), Date.new(2025, 12, 31)],
  [:matias, Date.new(2024,  7, 1), Date.new(2024, 12, 31)],
  [:matias, Date.new(2025,  1, 1), Date.new(2025,  6, 30)],
  [:matias, Date.new(2025,  7, 1), Date.new(2025, 12, 31)],
].each do |key, ps, pe|
  timeline << { type: :trading_fee, investor: key, period_start: ps, period_end: pe, apply_date: pe }
end

# ANNUAL fees: Laura, Sofía
[
  [:laura, Date.new(2024, 1, 1), Date.new(2024, 12, 31)],
  [:laura, Date.new(2025, 1, 1), Date.new(2025, 12, 31)],
  [:sofia, Date.new(2024, 1, 1), Date.new(2024, 12, 31)],
  [:sofia, Date.new(2025, 1, 1), Date.new(2025, 12, 31)],
].each do |key, ps, pe|
  timeline << { type: :trading_fee, investor: key, period_start: ps, period_end: pe, apply_date: pe }
end

# MONTHLY fees: Carlos (Jul 2024 – Jan 2026), Diego (Sep 2024 – Jan 2026)
[
  { key: :carlos, start: Date.new(2024, 7, 1), months: 19 },
  { key: :diego,  start: Date.new(2024, 9, 1), months: 17 },
].each do |cfg|
  cfg[:months].times do |i|
    month_start = cfg[:start] >> i
    month_end   = month_start.end_of_month
    timeline << { type: :trading_fee, investor: cfg[:key], period_start: month_start, period_end: month_end, apply_date: month_end }
  end
end

# Deactivate Nicolás after Q3 2025 fee is applied
timeline << { type: :deactivate, investor: :nicolas, date: Date.new(2025, 10, 1) }

# Sort by effective date, then by type priority
timeline.sort_by! { |e| [e[:apply_date] || e[:date], TYPE_PRIORITY[e[:type]]] }

# ── Process timeline ──────────────────────────────────────────────────────────

puts "\nProcessing #{timeline.size} events..."
dot = 0

timeline.each do |event|
  case event[:type]
  when :deposit
    apply_cash!(investor: investors[event[:investor]], request_type: 'DEPOSIT',
                amount: event[:amount], date: event[:date])

  when :withdrawal
    apply_cash!(investor: investors[event[:investor]], request_type: 'WITHDRAWAL',
                amount: event[:amount], date: event[:date])

  when :referral
    apply_referral!(investor: investors[event[:investor]], amount: event[:amount], date: event[:date])

  when :dor
    apply_dor!(admin: admin, date: event[:date], pct: event[:pct])
    dot += 1
    print '.' if (dot % 5).zero?

  when :trading_fee
    apply_trading_fee!(
      investor:     investors[event[:investor]],
      admin:        admin,
      period_start: event[:period_start],
      period_end:   event[:period_end],
      apply_date:   event[:apply_date],
    )

  when :deactivate
    investors[event[:investor]].update!(status: 'INACTIVE')
    puts "\n  → #{investors[event[:investor]].name} deactivated"
  end
end

# ── Final recalculation ───────────────────────────────────────────────────────

puts "\n\nRecalculating all portfolios..."
investors.each_value do |inv|
  inv.reload
  PortfolioRecalculator.recalculate!(inv)
  p = inv.portfolio
  puts "  #{inv.name.ljust(20)} balance: $#{"%.2f" % p.current_balance}  invested: $#{"%.2f" % p.total_invested}  return: $#{"%.2f" % p.accumulated_return_usd}"
end

# ── Summary ───────────────────────────────────────────────────────────────────

puts "\n✅ Done!"
puts "  Investors:           #{Investor.count} (#{Investor.where(status: 'ACTIVE').count} active)"
puts "  DOR records:         #{DailyOperatingResult.count}"
puts "  Portfolio histories: #{PortfolioHistory.count}"
puts "  Trading fees:        #{TradingFee.count}"
puts "  Requests:            #{InvestorRequest.count}"
