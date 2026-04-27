namespace :portfolios do
  desc "Recalcula total_invested (replay secuencial con piso en 0 en retiros/reversos) y saldos desde PortfolioHistory"
  task recalculate_total_invested: :environment do
    puts "Recalculando portfolios desde historial (PortfolioRecalculator)..."
    puts ""

    Investor.includes(:portfolio).find_each do |investor|
      next unless investor.portfolio

      old_total = investor.portfolio.total_invested.to_f
      PortfolioRecalculator.recalculate!(investor)
      new_total = investor.portfolio.reload.total_invested.to_f

      next if old_total == new_total

      puts "✓ #{investor.name} (#{investor.email})"
      puts "  total_invested Antes: $#{old_total} → Ahora: $#{new_total}"
      puts ""
    end

    puts "✅ Recálculo completado"
  end
end
