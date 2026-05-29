# frozen_string_literal: true

namespace :monthly_annex do
  desc 'Import historical monthly annex rows from db/seeds/monthly_annex_rows.json'
  task import: :environment do
    importer = MonthlyAnnexImporter.new
    if importer.import!
      puts "Imported #{importer.imported_count} rows."
    else
      puts "Imported #{importer.imported_count} rows with #{importer.errors.size} errors:"
      importer.errors.each { |e| puts "  - #{e}" }
      exit 1
    end
  end
end
