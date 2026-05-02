# frozen_string_literal: true

# Import investor + portfolio snapshot from the Genesis control Excel.
#
# Expected layout (sheet 1):
#   Row 1: Spanish titles (ignored for mapping)
#   Row 2: English keys — mail, investor_name, first_entry_date, total_profit_pct,
#          last_trading_fee_date, portfolio_after_last_fee, capital_current_usd,
#          total_deposits_usd, total_withdrawals_usd, total_profit_usd,
#          balance_jan_1_2026_usd, deposits_2026_usd, withdrawals_2026_usd,
#          profit_2026_usd, profit_2026_pct
#
# Usage:
#   GENESIS_XLSX_PATH=/path/Base.xlsx bundle exec rails investors:import_genesis_sheet
#
# Env:
#   GENESIS_XLSX_PATH — required path to .xlsx
#   GENESIS_INVESTOR_PASSWORD — optional; if set (min 6 chars), assigned to every imported investor
#   GENESIS_SNAPSHOT_DATE — optional, default 2026-04-30 (only when creating initial DEPOSIT history)
#   GENESIS_DRY_RUN=1 — print only, no DB writes
#
# Suggested portal password (change after first login): Winbit.Portal26
namespace :investors do
  desc 'Import / update investors and portfolios from Genesis Excel (see lib/tasks/genesis_sheet_import.rake header)'
  task import_genesis_sheet: :environment do
    path = ENV.fetch('GENESIS_XLSX_PATH', nil)
    raise 'Set GENESIS_XLSX_PATH to the .xlsx file' if path.blank? || !File.file?(path)

    begin
      require 'roo'
    rescue LoadError
      raise LoadError, 'Add gem "roo" and run bundle install'
    end

    dry = ENV['GENESIS_DRY_RUN'].to_s == '1'
    pwd = ENV['GENESIS_INVESTOR_PASSWORD'].to_s
    pwd = nil if pwd.length < 6

    snapshot_date = GenesisSheetImporter.parse_snapshot_date(ENV['GENESIS_SNAPSHOT_DATE'].presence || '2026-04-30')
    genesis_time = Time.zone.local(snapshot_date.year, snapshot_date.month, snapshot_date.day, 19, 0, 0)

    xlsx = Roo::Spreadsheet.open(path, extension: :xlsx)
    sheet = xlsx.sheet(0)
    headers = sheet.row(2).map { |c| GenesisSheetImporter.normalize_header(c) }

    processed = 0
    (3..sheet.last_row).each do |i|
      row = sheet.row(i)
      next if row.all? { |c| c.nil? || c.to_s.strip.empty? }

      h = headers.zip(row).to_h
      email = h['mail'].to_s.strip.downcase.presence
      next if email.blank?

      processed += 1
      GenesisSheetImporter.new(h, email:, pwd:, genesis_time:, dry:).call
    end

    puts "\nDone. Rows processed: #{processed}#{dry ? ' (dry run)' : ''}"
  end
end
