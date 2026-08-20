# frozen_string_literal: true

namespace :monthly_report_pdfs do
  desc 'Import monthly report PDFs from DIR for MONTH=YYYY-MM. Optional OVERRIDES JSON / OVERRIDES_FILE, PREVIEW=1'
  task import: :environment do
    dir = ENV.fetch('DIR')
    month = ENV.fetch('MONTH')
    preview = ActiveModel::Type::Boolean.new.cast(ENV.fetch('PREVIEW', 'false'))
    overrides = {}

    if ENV['OVERRIDES_FILE'].present?
      overrides.merge!(JSON.parse(File.read(ENV['OVERRIDES_FILE'])))
    end
    if ENV['OVERRIDES'].present?
      overrides.merge!(JSON.parse(ENV['OVERRIDES']))
    end

    uploader = InvestorMonthlyReportPdfs::DirectoryImporter.new(
      dir: dir,
      month: month,
      email_overrides: overrides,
      preview: preview
    ).call

    summary = uploader.summary
    puts "month=#{summary[:month]} preview=#{summary[:preview]}"
    puts "uploaded=#{summary[:uploaded_count]} replaced=#{summary[:replaced_count]} skipped=#{summary[:skipped_count]} errors=#{summary[:error_count]}"

    summary[:assignments].each do |row|
      investor = row[:investor]
      if investor
        puts "  #{row[:status]}  #{row[:filename]} -> #{investor[:email]} (#{investor[:name]})"
      else
        puts "  skip    #{row[:filename]} (#{row[:reason]})"
      end
    end

    summary[:errors].each do |row|
      puts "  error   #{row[:filename]} (#{row[:error]})"
    end
  end
end
