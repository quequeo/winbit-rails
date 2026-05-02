# frozen_string_literal: true

require 'bigdecimal'

# Imports one investor row from the Genesis control spreadsheet (see rake investors:import_genesis_sheet).
class GenesisSheetImporter
  def self.normalize_header(cell)
    s = cell.to_s.strip.downcase.gsub(/\s+/, '_')
    s.delete_suffix!('_') while s.end_with?('_')
    s
  end

  def self.parse_snapshot_date(s)
    Date.parse(s)
  rescue StandardError
    Date.new(2026, 4, 30)
  end

  def initialize(row_hash, email:, pwd:, genesis_time:, dry:)
    @h = row_hash
    @email = email
    @pwd = pwd
    @genesis_time = genesis_time
    @dry = dry
  end

  def call
    name = @h['investor_name'].to_s.strip.presence || @email.split('@').first.titleize

    cap = parse_money(@h['capital_current_usd'])
    dep = parse_money(@h['total_deposits_usd'])
    wdr = parse_money(@h['total_withdrawals_usd']) || BigDecimal('0')
    tot_profit_usd = parse_money(@h['total_profit_usd'])
    tot_profit_pct = parse_percent_points(@h['total_profit_pct'])
    p26_usd = parse_money(@h['profit_2026_usd'])
    p26_pct = parse_percent_points(@h['profit_2026_pct'])
    vpcust = parse_money(@h['portfolio_after_last_fee'])
    fee_at = parse_fee_basis_at(@h['last_trading_fee_date'])

    if cap.nil? || dep.nil?
      puts "SKIP #{@email} — missing capital_current_usd or total_deposits_usd"
      return
    end

    acc_usd = tot_profit_usd || (cap - dep + wdr).round(2, :half_up)
    acc_pct =
      if tot_profit_pct.nil?
        dep.positive? ? ((acc_usd / dep) * 100).round(4, :half_up).to_f : 0.0
      else
        tot_profit_pct
      end

    strat_all_usd = tot_profit_usd || acc_usd
    strat_all_pct = tot_profit_pct.nil? ? acc_pct : tot_profit_pct
    ytd_usd = p26_usd || BigDecimal('0')
    ytd_pct = p26_pct.nil? ? 0.0 : p26_pct

    puts "#{@email} | sheet: vpcust=#{vpcust || '—'} fee_basis_at=#{fee_at&.strftime('%Y-%m-%d %H:%M') || '—'} " \
         "capital=#{cap.to_f} deposits=#{dep.to_f} withdrawals=#{wdr.to_f} profit_usd=#{acc_usd.to_f}"

    return puts('  (dry run — no save)') if @dry

    investor = Investor.find_or_initialize_by(email: @email)
    investor.name = name
    investor.status = 'ACTIVE'
    investor.password = @pwd if @pwd.present?
    investor.save!

    p = investor.portfolio || investor.build_portfolio
    p.update!(
      current_balance: cap.to_f,
      total_invested: dep.to_f,
      accumulated_return_usd: acc_usd.to_f,
      accumulated_return_percent: acc_pct.to_f,
      annual_return_usd: ytd_usd.to_f,
      annual_return_percent: ytd_pct.to_f,
      strategy_return_all_usd: strat_all_usd.to_f,
      strategy_return_all_percent: strat_all_pct.to_f,
      strategy_return_ytd_usd: ytd_usd.to_f,
      strategy_return_ytd_percent: ytd_pct.to_f,
      genesis_vpcust_usd: vpcust&.to_f,
      genesis_fee_basis_at: fee_at
    )

    seed_genesis_history_if_empty!(investor, dep:, cap:)

    snap = InvestorPendingProfit.fee_reset_snapshot(investor: investor.reload, as_of: Time.current)
    puts "  fee_basis_used: vpcust=#{snap[:vpcust].to_s('F')} @ #{snap[:reset_at]&.iso8601 || '—'}"

    puts "  OK #{@email}"
  end

  private

  def seed_genesis_history_if_empty!(investor, dep:, cap:)
    return if investor.portfolio_histories.exists?

    InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      amount: dep,
      method: 'USDT',
      network: 'TRC20',
      status: 'APPROVED',
      requested_at: @genesis_time,
      processed_at: @genesis_time,
      notes: 'genesis sheet import'
    )

    PortfolioHistory.create!(
      investor: investor,
      event: 'DEPOSIT',
      amount: dep,
      previous_balance: 0,
      new_balance: cap,
      status: 'COMPLETED',
      date: @genesis_time
    )
  end

  def parse_percent_points(raw)
    return nil if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)

    f = BigDecimal(raw.to_s).to_f
    return nil if f.nan?

    if f.abs.positive? && f.abs < 10
      (f * 100).round(4, :half_up).to_f
    else
      f.round(4, :half_up).to_f
    end
  end

  def parse_money(raw)
    return nil if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)

    s = raw.to_s.strip.downcase
    return nil if s.match?(/[a-záéíóúñ]/)

    BigDecimal(raw.to_s).round(2, :half_up)
  rescue StandardError
    nil
  end

  def parse_fee_basis_at(raw)
    return nil if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)

    s = raw.to_s.strip.downcase
    return nil if s.match?(/[a-záéíóúñ]/)

    if raw.is_a?(DateTime) || raw.is_a?(Time) || raw.is_a?(ActiveSupport::TimeWithZone)
      return raw.in_time_zone.change(hour: 19, min: 0, sec: 0)
    end

    if raw.is_a?(Date)
      return Time.zone.local(raw.year, raw.month, raw.day, 19, 0, 0)
    end

    d = Date.strptime(s, '%d/%m/%Y')
    Time.zone.local(d.year, d.month, d.day, 19, 0, 0)
  rescue StandardError
    t = Time.zone.parse(s)
    t&.change(hour: 19, min: 0, sec: 0)
  rescue StandardError
    nil
  end
end
