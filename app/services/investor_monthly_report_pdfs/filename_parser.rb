# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  class FilenameParser
    Result = Struct.new(:ok, :investor_name, :month_number, :year, :skip_reason, keyword_init: true)

    PATTERN = /
      \A
      reporte
      \s+
      (?<month_name>[a-zA-ZáéíóúÁÉÍÓÚñÑ]+)
      (?:\s+(?<year>\d{4}))?
      \s*
      [-–—]
      \s*
      (?<name>.+?)
      \.pdf
      \z
    /ix

    def self.parse(filename)
      new(filename).parse
    end

    def initialize(filename)
      @filename = File.basename(Month.utf8(filename)).strip
    end

    def parse
      match = PATTERN.match(@filename)
      return failure('unparseable_filename') unless match

      month_number = Month.number_from_spanish(match[:month_name])
      return failure('unknown_month') unless month_number

      name = match[:name].to_s.strip
      return failure('missing_name') if name.blank?

      Result.new(
        ok: true,
        investor_name: name,
        month_number: month_number,
        year: match[:year]&.to_i
      )
    end

    private

    def failure(reason)
      Result.new(ok: false, skip_reason: reason)
    end
  end
end
