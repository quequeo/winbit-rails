#!/usr/bin/env ruby
# Genesis seed: sets day-zero snapshot for an investor.
#
# Sets the initial portfolio values and creates one DEPOSIT PortfolioHistory
# entry so the evolution chart has a starting point.
#
# From this point forward, daily operating results (DailyOperatingResultApplicator)
# will compound the strategy return fields automatically.
#
# Run:
#   heroku run rails runner db/seeds/seed_genesis.rb -a winbit-rails-55a941b2fe50

require 'bigdecimal'

# ─── CONFIGURATION ─────────────────────────────────────────────────────────────
INVESTOR_EMAIL    = 'CHANGE_ME@example.com'
INVESTOR_NAME     = 'Tu Nombre'
INVESTOR_PASSWORD = 'changeme123'

GENESIS_DATE      = Date.new(2026, 4, 1)

CURRENT_BALANCE              = 6_000.00
TOTAL_INVESTED               = 5_500.00
STRATEGY_RETURN_ALL_PERCENT  = 32.0
STRATEGY_RETURN_ALL_USD      = 500.0
STRATEGY_RETURN_YTD_PERCENT  = 3.66
STRATEGY_RETURN_YTD_USD      = 200.0
# ───────────────────────────────────────────────────────────────────────────────

def tz_time(y, m, d, hh, mm = 0, ss = 0)
  Time.zone.local(y, m, d, hh, mm, ss)
end

# Ensure admin user exists
admin = User.find_or_create_by!(email: 'winbit.cfds@gmail.com') do |u|
  u.name = 'Winbit Admin'
  u.role = 'SUPERADMIN'
end

AppSetting.set(
  AppSetting::INVESTOR_NOTIFICATIONS_ENABLED,
  'false',
  description: 'Habilitar/deshabilitar notificaciones por email a inversores'
) unless AppSetting.find_by(key: AppSetting::INVESTOR_NOTIFICATIONS_ENABLED)

# Clean slate for this investor (idempotent)
ApplicationRecord.transaction do
  inv = Investor.find_by(email: INVESTOR_EMAIL)
  if inv
    PortfolioHistory.where(investor_id: inv.id).delete_all
    InvestorRequest.where(investor_id: inv.id).delete_all
    TradingFee.where(investor_id: inv.id).delete_all
    Portfolio.where(investor_id: inv.id).delete_all
    inv.delete
    puts "♻️  Cleaned existing data for #{INVESTOR_EMAIL}"
  end
end

# Create investor
investor = Investor.create!(
  email: INVESTOR_EMAIL,
  name: INVESTOR_NAME,
  status: 'ACTIVE',
  password: INVESTOR_PASSWORD,
  trading_fee_frequency: 'QUARTERLY',
  trading_fee_percentage: 30,
)

# Create portfolio with genesis snapshot
portfolio = Portfolio.create!(
  investor: investor,
  current_balance: CURRENT_BALANCE,
  total_invested: TOTAL_INVESTED,
  accumulated_return_usd: BigDecimal(CURRENT_BALANCE.to_s) - BigDecimal(TOTAL_INVESTED.to_s),
  accumulated_return_percent: TOTAL_INVESTED.positive? ? ((CURRENT_BALANCE - TOTAL_INVESTED) / TOTAL_INVESTED * 100).round(4) : 0,
  annual_return_usd: 0,
  annual_return_percent: 0,
  strategy_return_all_usd: STRATEGY_RETURN_ALL_USD,
  strategy_return_all_percent: STRATEGY_RETURN_ALL_PERCENT,
  strategy_return_ytd_usd: STRATEGY_RETURN_YTD_USD,
  strategy_return_ytd_percent: STRATEGY_RETURN_YTD_PERCENT,
)

# Create initial deposit as the genesis history entry (chart starting point)
genesis_time = tz_time(GENESIS_DATE.year, GENESIS_DATE.month, GENESIS_DATE.day, 19, 0, 0)

InvestorRequest.create!(
  investor: investor,
  request_type: 'DEPOSIT',
  amount: TOTAL_INVESTED,
  method: 'USDT',
  network: 'TRC20',
  status: 'APPROVED',
  requested_at: genesis_time,
  processed_at: genesis_time,
  notes: 'genesis',
)

PortfolioHistory.create!(
  investor: investor,
  event: 'DEPOSIT',
  amount: TOTAL_INVESTED,
  previous_balance: 0,
  new_balance: CURRENT_BALANCE,
  status: 'COMPLETED',
  date: genesis_time,
)

puts "\n=== Genesis seed complete ==="
puts "investor               = #{investor.email}"
puts "current_balance        = $#{portfolio.current_balance}"
puts "total_invested         = $#{portfolio.total_invested}"
puts "strategy_return_all    = #{portfolio.strategy_return_all_percent}% ($#{portfolio.strategy_return_all_usd})"
puts "strategy_return_ytd    = #{portfolio.strategy_return_ytd_percent}% ($#{portfolio.strategy_return_ytd_usd})"
puts ""
puts "API:"
puts "  GET /api/public/v1/investor/#{CGI.escape(investor.email)}"
puts "  GET /api/public/v1/investor/#{CGI.escape(investor.email)}/history"
