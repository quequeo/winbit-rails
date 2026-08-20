# frozen_string_literal: true

require 'zip'

module InvestorMonthlyReportPdfs
  class BulkUploader
    attr_reader :uploaded, :replaced, :skipped, :errors, :assignments

    def initialize(month:, uploads:, uploaded_by: nil, preview: false, email_overrides: {})
      @month = month
      @uploads = Array(uploads)
      @uploaded_by = uploaded_by
      @preview = preview
      @email_overrides = index_overrides(email_overrides)
      @uploaded = []
      @replaced = []
      @skipped = []
      @errors = []
      @assignments = []
      @matcher = NameMatcher.new
    end

    def call
      expand_uploads.each { |upload| process_upload(upload) }
      true
    end

    def summary
      public_assignments = @assignments.map { |row| row.except(:investor_record) }

      if @preview
        {
          month: @month,
          preview: true,
          assignments: public_assignments,
          counts: assignment_counts,
          uploaded_count: 0,
          replaced_count: 0,
          skipped_count: @skipped.size,
          error_count: @errors.size,
          uploaded: [],
          replaced: [],
          skipped: @skipped,
          errors: @errors
        }
      else
        {
          month: @month,
          preview: false,
          assignments: public_assignments,
          counts: assignment_counts,
          uploaded_count: @uploaded.size,
          replaced_count: @replaced.size,
          skipped_count: @skipped.size,
          error_count: @errors.size,
          uploaded: @uploaded,
          replaced: @replaced,
          skipped: @skipped,
          errors: @errors
        }
      end
    end

    private

    def assignment_counts
      {
        assign: @assignments.count { |row| row[:status] == 'assign' },
        replace: @assignments.count { |row| row[:status] == 'replace' },
        skip: @assignments.count { |row| row[:status] == 'skip' }
      }
    end

    def expand_uploads
      @uploads.flat_map { |upload| expand_upload(upload) }
    end

    def expand_upload(upload)
      filename = upload.filename.to_s
      return [ upload ] unless filename.downcase.end_with?('.zip')

      expand_zip(upload)
    rescue Zip::Error => e
      @errors << { filename: filename, error: "ZIP inválido: #{e.message}" }
      []
    end

    def expand_zip(upload)
      extracted = []
      Zip::File.open_buffer(upload.bytes) do |zip|
        zip.each do |entry|
          next if entry.directory? || entry.name.end_with?('/')

          inner_name = File.basename(Month.utf8(entry.name))
          next if inner_name.start_with?('.')
          next unless inner_name.downcase.end_with?('.pdf')

          extracted << Upload.new(filename: inner_name, bytes: entry.get_input_stream.read)
        end
      end
      extracted
    end

    def process_upload(upload)
      filename = upload.filename
      bytes = upload.bytes

      unless filename.downcase.end_with?('.pdf')
        record_skip(filename, 'not_pdf')
        return
      end

      if bytes.blank? || bytes.bytesize.zero?
        record_skip(filename, 'empty')
        return
      end

      if bytes.bytesize > InvestorMonthlyReportPdf::MAX_BYTES
        record_skip(filename, 'too_large')
        return
      end

      unless bytes.byteslice(0, 4).to_s.start_with?(InvestorMonthlyReportPdf::PDF_MAGIC)
        record_skip(filename, 'not_pdf')
        return
      end

      parsed = FilenameParser.parse(filename)
      unless parsed.ok
        record_skip(filename, parsed.skip_reason)
        return
      end

      expected_month_number = Month.number(@month)
      if parsed.month_number != expected_month_number
        record_skip(filename, 'month_mismatch', parsed_name: parsed.investor_name)
        return
      end

      if parsed.year.present? && parsed.year != Month.year(@month)
        record_skip(filename, 'year_mismatch', parsed_name: parsed.investor_name)
        return
      end

      investor = resolve_investor(filename, parsed.investor_name)
      unless investor
        return
      end
      already = InvestorMonthlyReportPdf.exists?(investor_id: investor.id, month: @month)
      status = already ? 'replace' : 'assign'
      payload = assignment_payload(
        filename: filename,
        parsed_name: parsed.investor_name,
        status: status,
        investor: investor
      )
      @assignments << payload.merge(investor_record: investor)

      if @preview
        return
      end

      persist!(upload, investor)
    rescue ActiveRecord::RecordInvalid => e
      @errors << { filename: filename, error: e.message }
    end

    def persist!(upload, investor)
      record = InvestorMonthlyReportPdf.find_or_initialize_by(investor: investor, month: @month)
      was_persisted = record.persisted?

      record.assign_attributes(
        original_filename: upload.filename,
        content_type: 'application/pdf',
        byte_size: upload.bytes.bytesize,
        pdf_data: upload.bytes,
        uploaded_by: @uploaded_by
      )
      record.save!

      row = {
        id: record.id,
        filename: upload.filename,
        investor_id: investor.id,
        investor_name: investor.name,
        investor_email: investor.email
      }

      if was_persisted
        @replaced << row
      else
        @uploaded << row
      end
    end

    def record_skip(filename, reason, parsed_name: nil)
      assignment = {
        filename: filename,
        parsedName: parsed_name,
        status: 'skip',
        reason: reason,
        alreadyHasPdf: false,
        investor: nil
      }
      @assignments << assignment
      row = { filename: filename, reason: reason }
      row[:investor_name] = parsed_name if parsed_name
      @skipped << row
    end

    def assignment_payload(filename:, parsed_name:, status:, investor:)
      {
        filename: filename,
        parsedName: parsed_name,
        status: status,
        reason: nil,
        alreadyHasPdf: status == 'replace',
        investor: {
          id: investor.id,
          name: investor.name,
          email: investor.email,
          status: investor.status
        }
      }
    end

    def resolve_investor(filename, parsed_name)
      override_email = override_email_for(filename, parsed_name)
      if override_email
        investor = Investor.find_by(email: override_email)
        unless investor
          record_skip(filename, 'override_investor_not_found', parsed_name: parsed_name)
          return nil
        end
        return investor
      end

      match = @matcher.find(parsed_name)
      unless match.investor
        record_skip(filename, match.reason, parsed_name: parsed_name)
        return nil
      end

      match.investor
    end

    def override_email_for(filename, parsed_name)
      lookup_keys_for(filename, parsed_name).each do |key|
        email = @email_overrides[key]
        return email if email.present?
      end
      nil
    end

    def index_overrides(raw)
      indexed = {}
      raw.to_h.each do |key, email|
        next if key.blank? || email.blank?

        normalized_email = email.to_s.strip.downcase
        lookup_keys_for(key.to_s, nil).each do |lookup_key|
          indexed[lookup_key] = normalized_email
        end
      end
      indexed
    end

    def lookup_keys_for(filename, parsed_name)
      basename = File.basename(Month.utf8(filename.to_s))
      [
        basename,
        NameMatcher.normalize(basename),
        parsed_name.to_s.strip.presence,
        NameMatcher.normalize(parsed_name.to_s)
      ].compact.uniq.reject(&:blank?)
    end
  end
end
