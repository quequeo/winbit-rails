module OperationDayCaptures
  class BulkUploader
    attr_reader :uploaded, :skipped, :errors, :sample_days

    def initialize(paths:, created_by: nil)
      @paths = Array(paths).flat_map { |path| expand_paths(path) }.uniq
      @created_by = created_by
      @uploaded = []
      @skipped = []
      @errors = []
      @sample_days = []
    end

    def call
      @paths.each { |path| process_file(path) }
      @sample_days = @uploaded.map { |row| row[:date] }.uniq.sort.last(8)
      true
    end

    def summary
      {
        uploaded_count: @uploaded.size,
        skipped_count: @skipped.size,
        error_count: @errors.size,
        uploaded: @uploaded,
        skipped: @skipped,
        errors: @errors,
        sample_days: @sample_days,
        skip_breakdown: @skipped.group_by { |row| row[:reason] }.transform_values(&:size),
      }
    end

    private

    def expand_paths(path)
      pathname = Pathname.new(path)
      return [] unless pathname.exist?

      if pathname.directory?
        pathname.glob('**/*.{png,PNG}').map(&:to_s)
      else
        [pathname.to_s]
      end
    end

    def process_file(path)
      filename = File.basename(path)
      parsed = FilenameParser.parse(filename)
      unless parsed.ok
        skip!(filename, parsed.skip_reason)
        return
      end

      unless StrategyOperation.exists?(operation_date: parsed.capture_date)
        skip!(filename, 'no_operation', date: parsed.capture_date, asset: parsed.asset)
        return
      end

      if OperationDayCapture.exists?(original_filename: filename)
        skip!(filename, 'already_attached', date: parsed.capture_date, asset: parsed.asset)
        return
      end

      result_label = resolve_result_label(parsed)
      bytes = File.binread(path)

      capture = OperationDayCapture.create!(
        capture_date: parsed.capture_date,
        asset: parsed.asset,
        result_label: result_label,
        original_filename: filename,
        content_type: 'image/png',
        byte_size: bytes.bytesize,
        image_data: bytes,
        created_by: @created_by,
      )

      @uploaded << {
        id: capture.id,
        filename: filename,
        date: parsed.capture_date.iso8601,
        asset: parsed.asset,
        result_label: result_label,
      }
    rescue ActiveRecord::RecordInvalid, Errno::ENOENT, Errno::EACCES => e
      @errors << { filename: filename, error: e.message }
    end

    def resolve_result_label(parsed)
      admin_label = StrategyOperation
        .where(operation_date: parsed.capture_date, asset: parsed.asset)
        .where.not(result_label: [nil, ''])
        .order(:created_at)
        .limit(1)
        .pick(:result_label)

      return admin_label if StrategyOperation::RESULT_LABELS.include?(admin_label.to_s)

      token = parsed.filename_result.to_s.strip.upcase
      return token if StrategyOperation::RESULT_LABELS.include?(token)

      nil
    end

    def skip!(filename, reason, date: nil, asset: nil)
      @skipped << {
        filename: filename,
        reason: reason,
        date: date&.iso8601,
        asset: asset,
      }
    end
  end
end
