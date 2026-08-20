# frozen_string_literal: true

class InvestorMonthlyReportPdfSerializer
  def initialize(record)
    @record = record
    @investor = record.investor
  end

  def as_json(*)
    {
      id: record.id,
      month: record.month,
      originalFilename: record.original_filename,
      contentType: record.content_type,
      byteSize: record.byte_size,
      uploadedAt: record.updated_at,
      investor: {
        id: investor.id,
        name: investor.name,
        email: investor.email,
        status: investor.status
      }
    }
  end

  private

  attr_reader :record, :investor
end
