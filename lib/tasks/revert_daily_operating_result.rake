# frozen_string_literal: true

namespace :operating do
  desc <<~DESC.squish
    Revert one daily operating result. Sets balances/strategy fields back as if it had not been applied.
    Usage: REVERT_DATE=2026-05-01 bin/rails operating:revert_daily
    Dry run: REVERT_DATE=2026-05-01 DRY_RUN=1 bin/rails operating:revert_daily
  DESC
  task revert_daily: :environment do
    date_s = ENV.fetch('REVERT_DATE') { raise 'Set REVERT_DATE=YYYY-MM-DD' }
    date = Date.iso8601(date_s)
    dry = ENV['DRY_RUN'].present?

    puts "#{dry ? 'DRY RUN — ' : ''}Reverting daily operating result for #{date}…"

    result = DailyOperatingResultReverter.run!(date: date, dry_run: dry)

    unless result.ok
      puts "ERROR: #{result.error}"
      exit 1
    end

    p = result.preview
    puts "  movement_at: #{p[:movement_at]}"
    puts "  percent was: #{p[:percent]}%"
    puts "  investors affected: #{p[:investors]}"
    puts dry ? 'No changes written (dry run).' : 'Done.'
  end
end
