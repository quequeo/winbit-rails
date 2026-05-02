# frozen_string_literal: true

# Apply Genesis snapshot (30/04/2026) for all investors from the control spreadsheet.
#
# This task is idempotent: it upserts Investor + Portfolio rows and seeds an initial
# DEPOSIT PortfolioHistory entry only when the investor has no history yet.
#
# Usage (Heroku production):
#   heroku run rails investors:apply_genesis_sheet -a winbit-rails
#
# Optional env vars:
#   GENESIS_INVESTOR_PASSWORD — sets a portal password for every investor (default 'Winbit.Portal26', min 6 chars)
#   GENESIS_DRY_RUN=1         — log only, no DB writes
#
# Source: control spreadsheet "Base información (1).xlsx", snapshot at 2026-04-30.

namespace :investors do
  desc 'Apply Genesis sheet snapshot (30/04/2026) to investors / portfolios'
  task apply_genesis_sheet: :environment do
    GenesisSheetApply.run!(
      password: ENV['GENESIS_INVESTOR_PASSWORD'].presence || 'Winbit.Portal26',
      dry: ENV['GENESIS_DRY_RUN'].to_s == '1',
      snapshot_date: Date.new(2026, 4, 30),
    )
  end

  desc 'Wipe pre-Genesis test history (PortfolioHistory / TradingFee / DailyOperatingResult / InvestorRequest before 2026-04-30) and reseed Genesis DEPOSIT for managed investors'
  task clean_pre_genesis: :environment do
    GenesisCleanup.run!(dry: ENV['GENESIS_DRY_RUN'].to_s == '1')
  end
end

class GenesisSheetApply
  # Each row: snapshot at 2026-04-30 from the control spreadsheet.
  # cap = capital_current_usd, dep = total_deposits_usd, wdr = total_withdrawals_usd,
  # vpcust + last_fee = base for next trading fee (nil when there has been no fee charge),
  # bal_jan = balance on 2026-01-01 (used to derive 2026 USD/% strategy fields).
  ROWS = [
    { email: 'eugenio.carrio7@gmail.com',           name: 'Eugenio Carrió',         cap: 6484,  dep: 5445,  wdr: 1400,  vpcust: 3142,  last_fee: '2025-06-11', bal_jan: 6044,  dep26: 0,    wdr26: 0    },
    { email: 'mariano.kr@gmail.com',                name: 'Mariano Krokante',       cap: 1760,  dep: 701,   wdr: 0,     vpcust: nil,   last_fee: nil,          bal_jan: 1641,  dep26: 0,    wdr26: 0    },
    { email: 'luzmeder@gmail.com',                  name: 'Luz Meder',              cap: 1482,  dep: 1463,  wdr: 600,   vpcust: 912,   last_fee: '2024-03-26', bal_jan: 1381,  dep26: 0,    wdr26: 0    },
    { email: 'gustavooscarzuccotti@gmail.com',      name: 'Gustavo Zuccotti',       cap: 597,   dep: 2823,  wdr: 3081,  vpcust: nil,   last_fee: nil,          bal_jan: 1558,  dep26: 0,    wdr26: 1021 },
    { email: 'agoscarrio@hotmail.com',              name: 'Agostina Carrió',        cap: 2105,  dep: 960,   wdr: 0,     vpcust: nil,   last_fee: nil,          bal_jan: 1962,  dep26: 0,    wdr26: 0    },
    { email: 'miri.ana@hotmail.com',                name: 'Miriam',                 cap: 6314,  dep: 2880,  wdr: 0,     vpcust: nil,   last_fee: nil,          bal_jan: 5886,  dep26: 0,    wdr26: 0    },
    { email: 'aguilarjuanpablo13@gmail.com',        name: 'Juan Pablo Aguilar',     cap: 3145,  dep: 1800,  wdr: 0,     vpcust: nil,   last_fee: nil,          bal_jan: 2932,  dep26: 0,    wdr26: 0    },
    { email: 'leoneldaglio@gmail.com',              name: 'Leonel Daglio',          cap: 56525, dep: 45338, wdr: 0,     vpcust: 52690, last_fee: '2026-01-01', bal_jan: 52690, dep26: 0,    wdr26: 0    },
    { email: 'fabrabr190987@gmail.com',             name: 'Fabrizio Bruno',         cap: 7357,  dep: 5430,  wdr: 0,     vpcust: 7178,  last_fee: '2026-04-01', bal_jan: 6951,  dep26: 0,    wdr26: 0    },
    { email: 'cgiordano.ontb@gmail.com',            name: 'Camilo Giordano',        cap: 8188,  dep: 5050,  wdr: 0,     vpcust: 7989,  last_fee: '2026-04-01', bal_jan: 7736,  dep26: 0,    wdr26: 0    },
    { email: 'manuel.giordano87@gmail.com',         name: 'Manuel Giordano',        cap: 1639,  dep: 1010,  wdr: 0,     vpcust: 1599,  last_fee: '2026-04-01', bal_jan: 1548,  dep26: 0,    wdr26: 0    },
    { email: 'serialfoodie.contact@gmail.com',      name: 'Sergio Nicolás Torres',  cap: 1030,  dep: 3266,  wdr: 3820,  vpcust: 960,   last_fee: '2026-04-21', bal_jan: 1991,  dep26: 0,    wdr26: 1050 },
    { email: 'daniel_genoni@hotmail.com',           name: 'Daniel Genoni',          cap: 10755, dep: 7250,  wdr: 0,     vpcust: 10492, last_fee: '2026-04-01', bal_jan: 10161, dep26: 0,    wdr26: 0    },
    { email: 'marinacolabianchi@hotmail.com',       name: 'Marina Colabianchi',     cap: 6632,  dep: 4455,  wdr: 0,     vpcust: 6470,  last_fee: '2026-04-01', bal_jan: 6265,  dep26: 0,    wdr26: 0    },
    { email: 'tuliocapparelli@gmail.com',           name: 'Tulio Capparelli',       cap: 7474,  dep: 8531,  wdr: 2900,  vpcust: 7291,  last_fee: '2026-04-01', bal_jan: 7061,  dep26: 0,    wdr26: 0    },
    { email: 'aguslancia@gmail.com',                name: 'Agustina Lancia',        cap: 2871,  dep: 2251,  wdr: 0,     vpcust: 2801,  last_fee: '2026-04-01', bal_jan: 2712,  dep26: 0,    wdr26: 0    },
    { email: 'luismc90@gmail.com',                  name: 'Luis Matías Crocci',     cap: 15411, dep: 31459, wdr: 19543, vpcust: 14780, last_fee: '2026-04-01', bal_jan: 19806, dep26: 125,  wdr26: 5493 },
    { email: 'zuccottimacarena@gmail.com',          name: 'Macarena Zuccotti',      cap: 23440, dep: 18449, wdr: 0,     vpcust: nil,   last_fee: nil,          bal_jan: 21477, dep26: 400,  wdr26: 0    },
    { email: 'florzuccotti@gmail.com',              name: 'Florencia Zuccotti',     cap: 1862,  dep: 1500,  wdr: 0,     vpcust: nil,   last_fee: nil,          bal_jan: 1436,  dep26: 300,  wdr26: 0    },
    { email: 'ailinre28@gmail.com',                 name: 'Evelyn Reale',           cap: 1469,  dep: 1300,  wdr: 0,     vpcust: 1434,  last_fee: '2026-04-01', bal_jan: 1388,  dep26: 0,    wdr26: 0    },
    { email: 'julipirri@hotmail.com',               name: 'Julieta Pirri',          cap: 558,   dep: 500,   wdr: 0,     vpcust: 544,   last_fee: '2026-04-01', bal_jan: 527,   dep26: 0,    wdr26: 0    },
    { email: 'vigoliana@hotmail.com',               name: 'Lia Ana Vigo',           cap: 8878,  dep: 7923,  wdr: 0,     vpcust: 8661,  last_fee: '2026-04-01', bal_jan: 8368,  dep26: 0,    wdr26: 0    },
    { email: 'julia_vigo@yahoo.com.ar',             name: 'Julia Ana Vigo',         cap: 20770, dep: 18850, wdr: 0,     vpcust: 20264, last_fee: '2026-04-01', bal_jan: 15685, dep26: 4000, wdr26: 0    },
    { email: 'lisandro.filardi.1986@gmail.com',     name: 'Lisandro Filardi',       cap: 22993, dep: 25000, wdr: 4737,  vpcust: 22433, last_fee: '2026-04-01', bal_jan: 25187, dep26: 0,    wdr26: 3500 },
    { email: 'darioagustin2013@gmail.com',          name: 'Darío Agustín Vázquez',  cap: 3471,  dep: 3291,  wdr: 0,     vpcust: 3386,  last_fee: '2026-04-01', bal_jan: 3291,  dep26: 0,    wdr26: 0    },
    { email: 'proveedores@harasdelsurcollege.com',  name: 'Federico Martín Boero',  cap: 1460,  dep: 1400,  wdr: 0,     vpcust: 1219,  last_fee: '2026-04-01', bal_jan: 1400,  dep26: 0,    wdr26: 0    },
    { email: 'larraniaga.nicolas@gmail.com',        name: 'Nicolás Larrañaga',      cap: 5126,  dep: 5000,  wdr: 0,     vpcust: 5000,  last_fee: '2026-04-13', bal_jan: nil,   dep26: 5000, wdr26: 0,   ytd_usd_override: 126, ytd_pct_override: 2.52 },
  ].freeze

  def self.run!(password:, dry:, snapshot_date:)
    raise 'GENESIS_INVESTOR_PASSWORD must be at least 6 chars' if password.to_s.length < 6

    genesis_time = Time.zone.local(snapshot_date.year, snapshot_date.month, snapshot_date.day, 19, 0, 0)
    pwd = password
    puts "Snapshot date: #{snapshot_date}#{dry ? ' (dry run)' : ''}"

    ROWS.each { |r| apply_row(r, pwd, genesis_time, dry) }

    puts "\nDone. #{ROWS.size} investors processed#{dry ? ' (dry run)' : ''}"
  end

  def self.apply_row(r, pwd, genesis_time, dry)
    cap = BigDecimal(r[:cap].to_s)
    dep = BigDecimal(r[:dep].to_s)
    wdr = BigDecimal((r[:wdr] || 0).to_s)

    acc_usd = (cap - dep + wdr).round(2, :half_up)
    acc_pct = dep.positive? ? ((acc_usd / dep) * 100).round(4, :half_up).to_f : 0.0

    bal_jan = r[:bal_jan].nil? ? nil : BigDecimal(r[:bal_jan].to_s)
    dep26 = BigDecimal((r[:dep26] || 0).to_s)
    wdr26 = BigDecimal((r[:wdr26] || 0).to_s)

    if r[:ytd_usd_override]
      ytd_usd = BigDecimal(r[:ytd_usd_override].to_s).round(2, :half_up)
      ytd_pct = r[:ytd_pct_override].to_f
    elsif bal_jan
      ytd_usd = (cap - bal_jan + wdr26 - dep26).round(2, :half_up)
      ytd_pct = bal_jan.positive? ? ((ytd_usd / bal_jan) * 100).round(4, :half_up).to_f : 0.0
    else
      ytd_usd = BigDecimal('0')
      ytd_pct = 0.0
    end

    fee_at = r[:last_fee] ? Time.zone.parse("#{r[:last_fee]} 19:00:00") : nil
    vpcust = r[:vpcust].nil? ? nil : BigDecimal(r[:vpcust].to_s).to_f

    puts format(
      '%<email>-40s | cap=%<cap>-9s dep=%<dep>-9s wdr=%<wdr>-9s acc=%<acc>-9s ytd=%<ytd>-9s vpcust=%<vpcust>-9s fee_at=%<fee_at>s',
      email: r[:email],
      cap: cap.to_f,
      dep: dep.to_f,
      wdr: wdr.to_f,
      acc: acc_usd.to_f,
      ytd: ytd_usd.to_f,
      vpcust: vpcust || '—',
      fee_at: fee_at&.strftime('%Y-%m-%d') || '—'
    )

    return if dry

    investor = Investor.find_or_initialize_by(email: r[:email])
    investor.name = r[:name]
    investor.status = 'ACTIVE'
    investor.password = pwd if investor.password_digest.blank?
    investor.save!

    p = investor.portfolio || investor.build_portfolio
    p.update!(
      current_balance: cap.to_f,
      total_invested: dep.to_f,
      accumulated_return_usd: acc_usd.to_f,
      accumulated_return_percent: acc_pct,
      annual_return_usd: ytd_usd.to_f,
      annual_return_percent: ytd_pct,
      strategy_return_all_usd: acc_usd.to_f,
      strategy_return_all_percent: acc_pct,
      strategy_return_ytd_usd: ytd_usd.to_f,
      strategy_return_ytd_percent: ytd_pct,
      genesis_vpcust_usd: vpcust,
      genesis_fee_basis_at: fee_at,
    )

    seed_genesis_history_if_empty!(investor, dep, cap, genesis_time)
  end

  def self.seed_genesis_history_if_empty!(investor, dep, cap, genesis_time)
    return if investor.portfolio_histories.exists?

    InvestorRequest.create!(
      investor: investor, request_type: 'DEPOSIT', amount: dep,
      method: 'USDT', network: 'TRC20', status: 'APPROVED',
      requested_at: genesis_time, processed_at: genesis_time,
      notes: 'genesis sheet snapshot'
    )

    PortfolioHistory.create!(
      investor: investor, event: 'DEPOSIT', amount: dep,
      previous_balance: 0, new_balance: cap,
      status: 'COMPLETED', date: genesis_time,
    )
  end
end

# Wipes all testing data before the Genesis snapshot and re-creates the
# initial DEPOSIT entry for every investor managed by GenesisSheetApply.
class GenesisCleanup
  CUTOFF = Time.zone.local(2026, 4, 30, 19, 0, 0)

  def self.run!(dry:)
    tf_scope  = TradingFee.where('applied_at < ?', CUTOFF)
    ph_scope  = PortfolioHistory.where('date < ?', CUTOFF)
    dor_scope = DailyOperatingResult.where('date < ?', CUTOFF.to_date)
    req_scope = InvestorRequest.where('requested_at < ?', CUTOFF)

    puts "Pre-Genesis cleanup (cutoff: #{CUTOFF})#{dry ? ' (dry run)' : ''}"
    puts "  TradingFee:           #{tf_scope.count}"
    puts "  PortfolioHistory:     #{ph_scope.count}"
    puts "  DailyOperatingResult: #{dor_scope.count}"
    puts "  InvestorRequest:      #{req_scope.count}"

    return if dry

    ActiveRecord::Base.transaction do
      tf_scope.update_all(withdrawal_request_id: nil)
      tf_scope.delete_all
      ph_scope.delete_all
      dor_scope.delete_all
      req_scope.delete_all

      reseed_genesis_history!
    end

    puts 'Done.'
  end

  def self.reseed_genesis_history!
    GenesisSheetApply::ROWS.each do |r|
      investor = Investor.find_by(email: r[:email])
      next unless investor
      next if investor.portfolio_histories.exists?

      dep = BigDecimal(r[:dep].to_s)
      cap = BigDecimal(r[:cap].to_s)

      InvestorRequest.create!(
        investor: investor, request_type: 'DEPOSIT', amount: dep,
        method: 'USDT', network: 'TRC20', status: 'APPROVED',
        requested_at: CUTOFF, processed_at: CUTOFF,
        notes: 'genesis sheet snapshot (post-cleanup)'
      )

      PortfolioHistory.create!(
        investor: investor, event: 'DEPOSIT', amount: dep,
        previous_balance: 0, new_balance: cap,
        status: 'COMPLETED', date: CUTOFF,
      )

      puts "  Reseeded genesis DEPOSIT for #{r[:email]}"
    end
  end
end
