# Seed initial admins

initial_admins = [
  { email: 'winbit.cfds@gmail.com', name: 'Winbit Admin', role: 'SUPERADMIN' },
  { email: 'jaimegarciamendez@gmail.com', name: 'Jaime García', role: 'SUPERADMIN' },
]

initial_admins.each do |admin|
  user = User.find_or_initialize_by(email: admin[:email])
  user.name = admin[:name]
  user.role = admin[:role]
  # provider/uid are set on first Google login (User.from_google_omniauth)
  user.provider = nil if user.respond_to?(:provider=)
  user.uid = nil if user.respond_to?(:uid=)
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

# Seed demo data for local development.
# Default is a minimal, deterministic scenario for Jaime (no withdrawals, no trading fees).
# To run the larger random demo seed, use: SEED_RANDOM_DEMO=true bin/rails db:seed
if Rails.env.development?
  if ENV['SEED_RANDOM_DEMO'] == 'true'
    puts "🌱 SEED_RANDOM_DEMO=true: random demo seed is disabled in this setup. Use db/seeds/demo_jaime_amegar_2025.rb instead."
  else
    puts "🌱 Seeding minimal scenario (development): Jaime deposit +20% operating result..."
    load Rails.root.join('db', 'seeds', 'demo_minimal_jaime_2026.rb')
  end
end
