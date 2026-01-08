namespace :investors do
  desc "Import investors data from spreadsheet"
  task import: :environment do
    data = [
      { code: '001', capital: 6074, return_total: 2029, return_pct: 37.3, return_annual: 854, return_annual_pct: 24.20 },
      { code: '002', capital: 1649, return_total: 948, return_pct: 135.3, return_annual: 320, return_annual_pct: 24.20 },
      { code: '003', capital: 1388, return_total: 525, return_pct: 35.9, return_annual: 269, return_annual_pct: 24.20 },
      { code: '004', capital: 1415, return_total: 802, return_pct: 28.4, return_annual: 400, return_annual_pct: 24.20 },
      { code: '005', capital: 1972, return_total: 1012, return_pct: 105.4, return_annual: 383, return_annual_pct: 24.20 },
      { code: '006', capital: 5915, return_total: 3035, return_pct: 105.4, return_annual: 1148, return_annual_pct: 24.20 },
      { code: '007', capital: 2947, return_total: 1147, return_pct: 63.7, return_annual: 569, return_annual_pct: 24.20 },
      { code: '008', capital: 52953, return_total: 7615, return_pct: 16.8, return_annual: 4878, return_annual_pct: 18.00 },
      { code: '009', capital: 6986, return_total: 1556, return_pct: 28.6, return_annual: 757, return_annual_pct: 16.60 },
      { code: '010', capital: 7775, return_total: 2725, return_pct: 54.0, return_annual: 1099, return_annual_pct: 16.60 },
      { code: '011', capital: 1556, return_total: 546, return_pct: 54.1, return_annual: 220, return_annual_pct: 16.60 },
      { code: '012', capital: 2001, return_total: 1485, return_pct: 45.5, return_annual: 526, return_annual_pct: 16.60 },
      { code: '013', capital: 10212, return_total: 2962, return_pct: 40.8, return_annual: 1443, return_annual_pct: 16.60 },
      { code: '014', capital: 6297, return_total: 1842, return_pct: 41.3, return_annual: 889, return_annual_pct: 16.60 },
      { code: '015', capital: 7096, return_total: 1465, return_pct: 17.2, return_annual: 994, return_annual_pct: 16.60 },
      { code: '016', capital: 2726, return_total: 475, return_pct: 21.1, return_annual: 377, return_annual_pct: 16.60 },
      { code: '017', capital: 19905, return_total: 2621, return_pct: 8.4, return_annual: 1814, return_annual_pct: 16.60 },
      { code: '018', capital: 21584, return_total: 3535, return_pct: 19.6, return_annual: 3246, return_annual_pct: 24.20 },
      { code: '019', capital: 1745, return_total: 245, return_pct: 16.3, return_annual: 236, return_annual_pct: 19.70 },
      { code: '020', capital: 1395, return_total: 95, return_pct: 7.3, return_annual: 88, return_annual_pct: 6.80 },
      { code: '021', capital: 530, return_total: 30, return_pct: 6.0, return_annual: 27, return_annual_pct: 5.40 },
      { code: '022', capital: 8410, return_total: 487, return_pct: 6.2, return_annual: 445, return_annual_pct: 5.60 },
      { code: '023', capital: 15763, return_total: 913, return_pct: 6.1, return_annual: 835, return_annual_pct: 5.60 },
      { code: '024', capital: 24857, return_total: 1594, return_pct: 6.4, return_annual: 1424, return_annual_pct: 7.30 },
      { code: '025', capital: 15314, return_total: 314, return_pct: 2.1, return_annual: 238, return_annual_pct: 1.60 },
      { code: '026', capital: 0, return_total: 0, return_pct: 0.0, return_annual: 0, return_annual_pct: 0.0 },
      { code: '027', capital: 3291, return_total: 205, return_pct: 6.6, return_annual: 153, return_annual_pct: 4.90 },
    ]

    puts "🚀 Importando #{data.size} inversores..."

    data.each do |row|
      email = "investor#{row[:code]}@winbit.com"

      investor = Investor.find_or_initialize_by(email: email)

      if investor.new_record?
        investor.name = "Inversor #{row[:code]}"
        investor.status = 'ACTIVE'
        investor.save!
        puts "  ✅ Creado inversor #{email}"
      else
        puts "  ℹ️  Inversor #{email} ya existe"
      end

      portfolio = investor.portfolio || investor.build_portfolio

      # Calcular total_invested a partir de: capital actual - rendimiento total
      total_invested = row[:capital] - row[:return_total]

      portfolio.update!(
        current_balance: row[:capital],
        total_invested: total_invested > 0 ? total_invested : 0,
        accumulated_return_usd: row[:return_total],
        accumulated_return_percent: row[:return_pct],
        annual_return_usd: row[:return_annual],
        annual_return_percent: row[:return_annual_pct],
      )

      puts "  💰 Actualizado portfolio: Capital $#{row[:capital]} | Retorno $#{row[:return_total]} (#{row[:return_pct]}%)"
    end

    puts "\n✅ Importación completada!"
    puts "📊 Total inversores: #{Investor.count}"
    puts "💵 Capital total: $#{Portfolio.sum(:current_balance).to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
end
