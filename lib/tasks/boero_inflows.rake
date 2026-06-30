# frozen_string_literal: true

namespace :boero do
  desc 'Inspect Federico Boero inflows (DEPOSIT requests since last fee reset)'
  task inspect_inflows: :environment do
    inv = Investor.find_by(email: 'proveedores@harasdelsurcollege.com')
    abort('Investor not found') unless inv

    p = inv.portfolio
    reset = InvestorPendingProfit.fee_reset_snapshot(investor: inv, as_of: Time.current)
    basis = InvestorPendingProfit.fee_basis_snapshot(
      investor: inv,
      as_of: Time.current,
      current_balance: p.current_balance
    )

    puts "balance=#{p.current_balance} genesis_vpcust=#{p.genesis_vpcust_usd} reset=#{reset.inspect}"
    puts "basis=#{basis.inspect}"
    puts '--- DEPOSITS ---'
    InvestorRequest.where(investor_id: inv.id, request_type: 'DEPOSIT', status: 'APPROVED')
                   .order(:processed_at)
                   .find_each do |r|
      puts "#{r.id} | amount=#{r.amount} | processed_at=#{r.processed_at} | notes=#{r.notes.inspect}"
    end
  end

  desc 'Fix Boero post-reset deposit inflows total to 400 USD (DRY_RUN=1 to preview only)'
  task fix_inflows: :environment do
    inv = Investor.find_by!(email: 'proveedores@harasdelsurcollege.com')
    portfolio = inv.portfolio
    reset_at = InvestorPendingProfit.fee_reset_snapshot(investor: inv, as_of: Time.current)[:reset_at]

    scope = InvestorRequest.where(investor_id: inv.id, request_type: 'DEPOSIT', status: 'APPROVED')
                           .where("COALESCE(notes, '') NOT ILIKE 'genesis sheet snapshot%'")
    scope = scope.where('processed_at > ?', reset_at) if reset_at

    deposits = scope.order(:processed_at).to_a
    total = deposits.sum { |r| BigDecimal(r.amount.to_s) }
    target = BigDecimal('400')

    puts "Post-reset deposits: #{deposits.size} row(s), total=#{total}, target=#{target}"

    if deposits.empty?
      abort('No post-reset deposit found to update')
    end

    if total == target
      puts 'Already at 400 — nothing to do'
      next
    end

    unless deposits.size == 1 && total == BigDecimal('200')
      abort("Unexpected deposit rows (#{deposits.size}, total=#{total}); fix manually")
    end

    dep = deposits.first
    old_amount = BigDecimal(dep.amount.to_s)
    delta = target - old_amount

    puts "Update InvestorRequest #{dep.id}: #{old_amount} -> #{target} (inflows only; balance unchanged)"

    if ENV['DRY_RUN'].to_s == '1'
      puts 'DRY_RUN=1 — no changes written'
      next
    end

    ApplicationRecord.transaction do
      dep.update!(amount: target.to_f)
    end

    basis = InvestorPendingProfit.fee_basis_snapshot(
      investor: inv.reload,
      as_of: Time.current,
      current_balance: inv.portfolio.current_balance
    )
    puts "Done. basis=#{basis.inspect}"
  end

  desc 'Revert mistaken +200 on Boero balance/history; keep InvestorRequest inflows at 400'
  task revert_balance_inflation: :environment do
    inv = Investor.find_by!(email: 'proveedores@harasdelsurcollege.com')
    portfolio = inv.portfolio
    target_balance = BigDecimal('1657.81')

    dep = InvestorRequest.find_by!(
      investor_id: inv.id,
      request_type: 'DEPOSIT',
      status: 'APPROVED',
      amount: 400
    )

    history = PortfolioHistory.where(investor_id: inv.id, event: 'DEPOSIT', status: 'COMPLETED')
                              .where('date >= ? AND date <= ?', dep.processed_at - 1.day, dep.processed_at + 1.day)
                              .order(date: :desc)
                              .first

    puts "current balance=#{portfolio.current_balance} target=#{target_balance}"
    puts "history=#{history&.id} amount=#{history&.amount} new_balance=#{history&.new_balance}"

    if ENV['DRY_RUN'].to_s == '1'
      puts 'DRY_RUN=1 — no changes written'
      next
    end

    ApplicationRecord.transaction do
      if history
        history.update!(
          amount: 200.0,
          new_balance: BigDecimal(history.new_balance.to_s) - BigDecimal('200')
        )
      end
      portfolio.update!(current_balance: target_balance.to_f)
    end

    basis = InvestorPendingProfit.fee_basis_snapshot(
      investor: inv.reload,
      as_of: Time.current,
      current_balance: inv.portfolio.current_balance
    )
    puts "Done. basis=#{basis.inspect}"
  end
end
