# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  class DirectoryImporter
    def initialize(dir:, month:, email_overrides: {}, preview: false, uploaded_by: nil)
      @dir = dir
      @month = month
      @email_overrides = email_overrides
      @preview = preview
      @uploaded_by = uploaded_by
    end

    def call
      raise ArgumentError, "DIR no es un directorio: #{@dir}" unless File.directory?(@dir)
      raise ArgumentError, "MONTH inválido: #{@month}" unless Month.valid?(@month)

      uploader = BulkUploader.new(
        month: @month,
        uploads: uploads_from_dir,
        uploaded_by: @uploaded_by,
        preview: @preview,
        email_overrides: @email_overrides
      )
      uploader.call
      uploader
    end

    private

    def uploads_from_dir
      Dir.children(@dir).filter_map do |name|
        next if name.start_with?('.')
        next unless name.downcase.end_with?('.pdf')

        path = File.join(@dir, name)
        next unless File.file?(path)

        Upload.new(filename: name, bytes: File.binread(path))
      end
    end
  end
end
