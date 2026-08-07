namespace :operation_day_captures do
  desc 'Bulk upload day-level operation screenshots from PNG folders (idempotent by filename)'
  task bulk_upload: :environment do
    roots = ENV.fetch('ROOTS', '').split(/[|;]/).map(&:strip).reject(&:blank?)
    if roots.empty?
      abort 'Set ROOTS to one or more directories/files separated by ; or |'
    end

    email = ENV.fetch('ADMIN_EMAIL', 'jaimegarciamendez@gmail.com')
    user = User.find_by(email: email)

    uploader = OperationDayCaptures::BulkUploader.new(paths: roots, created_by: user)
    uploader.call
    summary = uploader.summary

    puts "Uploaded: #{summary[:uploaded_count]}"
    puts "Skipped:  #{summary[:skipped_count]} #{summary[:skip_breakdown].inspect}"
    puts "Errors:   #{summary[:error_count]}"
    puts "Sample days: #{summary[:sample_days].join(', ')}"

    summary[:skipped].each do |row|
      puts "SKIP [#{row[:reason]}] #{row[:filename]}"
    end
    summary[:errors].each do |row|
      puts "ERROR #{row[:filename]}: #{row[:error]}"
    end
  end
end
