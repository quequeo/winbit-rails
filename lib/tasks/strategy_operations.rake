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

  desc 'Clear invalid opened_at/closed_at values (e.g. prices imported by mistake from Excel)'
  task sanitize_times: :environment do
    cleared = 0
    StrategyOperation.find_each do |operation|
      attrs = {}
      unless StrategyOperation.valid_time?(operation.opened_at)
        attrs[:opened_at] = nil if operation.opened_at.present?
      end
      unless StrategyOperation.valid_time?(operation.closed_at)
        attrs[:closed_at] = nil if operation.closed_at.present?
      end
      next if attrs.empty?

      operation.update_columns(attrs)
      cleared += 1
    end
    puts "Sanitized #{cleared} operations"
  end
end
