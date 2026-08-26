# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdf, type: :model do
  let!(:investor) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }

  def build_report(attrs = {})
    described_class.new(
      {
        investor: investor,
        month: '2026-07',
        original_filename: 'Reporte julio - TULIO CAPPARELLI.pdf',
        content_type: 'application/pdf',
        byte_size: 12,
        pdf_data: '%PDF-1.4 hi'
      }.merge(attrs)
    )
  end

  it 'persists a PDF for an investor and month' do
    report = build_report
    expect(report.save).to be(true)
    expect(report).to be_persisted
  end

  it 'rejects duplicate investor+month' do
    build_report.save!
    dup = build_report(pdf_data: '%PDF-1.4 other', byte_size: 15)
    expect(dup).not_to be_valid
    expect(dup.errors[:month]).to be_present
  end

  it 'rejects invalid month format' do
    report = build_report(month: '2026-13')
    expect(report).not_to be_valid
  end

  it 'rejects non-PDF payloads' do
    report = build_report(pdf_data: 'not-a-pdf', byte_size: 9)
    expect(report).not_to be_valid
    expect(report.errors[:pdf_data]).to be_present
  end

  it 'rejects files larger than 15MB' do
    report = build_report(byte_size: 15.megabytes + 1, pdf_data: '%PDF-1.4 x')
    expect(report).not_to be_valid
    expect(report.errors[:byte_size]).to be_present
  end

  it 'computes last closed month as previous calendar month' do
    travel_to Time.zone.local(2026, 8, 20, 12, 0, 0) do
      expect(described_class.last_closed_month).to eq('2026-07')
    end
  end

  it 'builds the email attachment filename with Spanish month, year and uppercase name' do
    report = build_report
    expect(report.email_attachment_filename).to eq('Reporte julio 2026 - TULIO CAPPARELLI.pdf')
  end
end
