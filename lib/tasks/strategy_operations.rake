namespace :strategy_operations do
  desc 'Import strategy operations from backtesting spreadsheet (only dates with admin daily operativa)'
  task import: :environment do
    path = ENV.fetch('FILE', Rails.root.join('data/backtesting_2026_mayo_junio.xlsx').to_s)
    email = ENV.fetch('ADMIN_EMAIL', 'jaimegarciamendez@gmail.com')
    user = User.find_by!(email: email)

    importer = StrategyOperations::Importer.new(path: path, created_by: user, replace_existing: true)
    if importer.call
      puts "Imported #{importer.imported_count} operations"
      puts "Skipped #{importer.skipped_count} rows"
      importer.warnings.each { |warning| puts "WARN: #{warning}" }
    else
      abort importer.errors.join(', ')
    end
  end
end
