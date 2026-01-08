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
