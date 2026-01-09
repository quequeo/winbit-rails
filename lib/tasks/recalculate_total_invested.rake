namespace :portfolios do
  desc "Recalculate total_invested for all investors (Deposits - Withdrawals)"
  task recalculate_total_invested: :environment do
    puts "Recalculando Total Invertido para todos los inversores..."
    puts "Nueva lógica: Total Invertido = Depósitos - Retiros"
    puts ""

    Investor.includes(:portfolio, :portfolio_histories).find_each do |investor|
      next unless investor.portfolio

      deposits = investor.portfolio_histories.where(event: 'DEPOSIT').sum(:amount).to_f
      withdrawals = investor.portfolio_histories.where(event: 'WITHDRAWAL').sum(:amount).to_f
      new_total_invested = deposits - withdrawals

      old_total = investor.portfolio.total_invested.to_f

      if old_total != new_total_invested
        investor.portfolio.update!(total_invested: new_total_invested)
        puts "✓ #{investor.name} (#{investor.email})"
        puts "  Depósitos: $#{deposits}"
        puts "  Retiros: $#{withdrawals}"
        puts "  Antes: $#{old_total} → Ahora: $#{new_total_invested}"
        puts ""
      end
    end

    puts "✅ Recálculo completado"
  end
end
