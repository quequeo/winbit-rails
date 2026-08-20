# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  class Upload
    attr_reader :filename, :bytes

    def initialize(filename:, bytes:)
      @filename = File.basename(Month.utf8(filename))
      @bytes = bytes.to_s.b
    end
  end
end
