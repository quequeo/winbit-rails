# Seed initial admins

initial_admins = [
  { email: 'winbit.cfds@gmail.com', name: 'Winbit Admin', role: 'SUPERADMIN' },
  { email: 'jaimegarciamendez@gmail.com', name: 'Jaime García', role: 'SUPERADMIN' },
]

initial_admins.each do |admin|
  user = User.find_or_initialize_by(email: admin[:email])
  user.name = admin[:name]
  user.role = admin[:role]
  user.save!
end

puts "✅ Seeded #{initial_admins.length} admin(s)"

# Seed app settings
AppSetting.set(
  AppSetting::INVESTOR_NOTIFICATIONS_ENABLED,
  'false',
  description: 'Habilitar/deshabilitar notificaciones por email a inversores'
)

AppSetting.set(
  AppSetting::INVESTOR_EMAIL_WHITELIST,
  ['jaimegarciamendez@gmail.com'],
  description: 'Lista de emails de inversores que siempre reciben notificaciones (para testing)'
)

puts "✅ Seeded app settings"

# Seed demo data for local development (fake investors, portfolios, histories, requests, wallets)
if Rails.env.development?
  require 'securerandom'
  require 'bigdecimal'

  def money(amount)
    BigDecimal(amount.to_s).round(2)
  end

  puts "🌱 Seeding demo data (development)..."

  wallet_configs = [
    { asset: 'USDT', network: 'TRC20', address: 'TDemoUSDTTRC20xxxxxxxxxxxxxxxxxxxx' },
    { asset: 'USDT', network: 'BEP20', address: '0xDEMO_USDT_BEP20_0000000000000000' },
    { asset: 'USDC', network: 'ERC20', address: '0xDEMO_USDC_ERC20_0000000000000000' },
    { asset: 'USDC', network: 'POLYGON', address: '0xDEMO_USDC_POLYGON_000000000000000' }
  ]

  wallet_configs.each do |w|
    wallet = Wallet.find_or_initialize_by(asset: w[:asset], network: w[:network])
    wallet.address = w[:address]
    wallet.enabled = true
    wallet.save!
  end

  demo_investors = [
    { email: 'demo.investor1@example.com', name: 'Demo Investor 1' },
    { email: 'demo.investor2@example.com', name: 'Demo Investor 2' },
    { email: 'demo.investor3@example.com', name: 'Demo Investor 3' },
    { email: 'demo.investor4@example.com', name: 'Demo Investor 4' }
  ]

  created_investors = 0
  created_histories = 0
  created_requests = 0

  ActiveRecord::Base.transaction do
    demo_investors.each do |attrs|
      investor = Investor.find_or_initialize_by(email: attrs[:email])
      investor.name = attrs[:name]
      investor.status = 'ACTIVE'
      created_investors += 1 if investor.new_record?
      investor.save!

      # Make demo seeding idempotent: only reset data for these demo investors.
      investor.portfolio_histories.delete_all
      investor.investor_requests.delete_all

      # Portfolio snapshot
      total_invested = money(rand(5_000..50_000))
      current_balance = money([total_invested + money(rand(-1_000..8_000)), 0].max)
      accumulated_usd = money(current_balance - total_invested)
      accumulated_percent = total_invested.zero? ? money(0) : money((accumulated_usd / total_invested) * 100)
      annual_percent = money(accumulated_percent / rand(1..3))
      annual_usd = total_invested.zero? ? money(0) : money((annual_percent / 100) * total_invested)

      portfolio = investor.portfolio || investor.build_portfolio
      portfolio.current_balance = current_balance
      portfolio.total_invested = total_invested
      portfolio.accumulated_return_usd = accumulated_usd
      portfolio.accumulated_return_percent = accumulated_percent
      portfolio.annual_return_usd = annual_usd
      portfolio.annual_return_percent = annual_percent
      portfolio.save!

      # Portfolio histories (simple, coherent balance evolution)
      balance = money(0)
      today = Time.zone.now.beginning_of_day

      deposits = Array.new(3) { money(rand(1_000..10_000)) }
      deposits.each_with_index do |amt, idx|
        prev = balance
        balance = money(balance + amt)
        investor.portfolio_histories.create!(
          date: today - (14 - idx * 5).days,
          event: 'DEPOSIT',
          amount: amt,
          previous_balance: prev,
          new_balance: balance,
          status: 'COMPLETED'
        )
        created_histories += 1
      end

      op_result = money(rand(50..1_500))
      prev = balance
      balance = money(balance + op_result)
      investor.portfolio_histories.create!(
        date: today - 2.days,
        event: 'OPERATING_RESULT',
        amount: op_result,
        previous_balance: prev,
        new_balance: balance,
        status: 'COMPLETED'
      )
      created_histories += 1

      # Requests
      investor.investor_requests.create!(
        request_type: 'DEPOSIT',
        amount: money(rand(500..5_000)),
        method: 'USDT',
        network: 'TRC20',
        status: 'PENDING',
        lemontag: '@demo',
        notes: 'Demo seed request'
      )
      created_requests += 1

      investor.investor_requests.create!(
        request_type: 'WITHDRAWAL',
        amount: money(rand(200..2_000)),
        method: 'USDC',
        network: 'ERC20',
        status: 'APPROVED',
        transaction_hash: "0x#{SecureRandom.hex(16)}",
        notes: 'Demo approved withdrawal',
        processed_at: Time.zone.now - 1.day
      )
      created_requests += 1

      investor.investor_requests.create!(
        request_type: 'DEPOSIT',
        amount: money(rand(200..3_000)),
        method: 'LEMON_CASH',
        status: 'REJECTED',
        notes: 'Demo rejected deposit',
        processed_at: Time.zone.now - 3.days
      )
      created_requests += 1
    end
  end

  puts "✅ Seeded demo investors: #{created_investors}"
  puts "✅ Seeded demo portfolio histories: #{created_histories}"
  puts "✅ Seeded demo requests: #{created_requests}"
  puts "✅ Seeded wallets: #{wallet_configs.length}"
end
