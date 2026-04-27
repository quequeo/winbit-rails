namespace :portfolios do
  desc "Lista inversores cuyo replay secuencial deja total_invested < 0 (no debería ocurrir). " \
       "Uso: bin/rails portfolios:audit_negative_total_invested"
  task audit_negative_total_invested: :environment do
    rows = []
    Investor.includes(:portfolio).find_each do |investor|
      next unless investor.portfolio

      breakdown = PortfolioRecalculator.total_invested_breakdown(investor.id)
      total = breakdown[:total_invested]
      next unless total.negative?

      rows << {
        investor: investor,
        breakdown: breakdown,
        stored_total: BigDecimal(investor.portfolio.total_invested.to_s),
      }
    end

    if rows.empty?
      puts "OK: ningún inversor tiene total_invested recalculado < 0 desde PortfolioHistory."
      next
    end

    puts "ATENCIÓN: #{rows.size} inversor(es) con total_invested secuencial NEGATIVO:"
    puts ""

    rows.each do |r|
      inv = r[:investor]
      b = r[:breakdown]
      puts "  id=#{inv.id}  #{inv.email}"
      puts "    nombre: #{inv.name}"
      puts "    DEPOSIT sum:           #{b[:deposits_sum].to_f}"
      puts "    REFERRAL_COMMISSION:   #{b[:referral_sum].to_f}"
      puts "    DEPOSIT_REVERSAL sum:  #{b[:deposit_reversals_sum].to_f}"
      puts "    WITHDRAWAL sum:        #{b[:withdrawals_sum].to_f}"
      puts "    => total_invested (histórico): #{b[:total_invested].to_f}  |  en portfolio (DB): #{r[:stored_total].to_f}"
      puts ""
    end

    puts "Corregir historial o depósitos iniciales antes de aplicar operativa diaria."
  end
end
