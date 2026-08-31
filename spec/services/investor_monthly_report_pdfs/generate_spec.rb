# frozen_string_literal: true

require 'rails_helper'

# Exercises the real wicked_pdf/wkhtmltopdf pipeline (no mocking of PDF
# rendering itself) - needs the wkhtmltopdf binary available locally
# (WKHTMLTOPDF_BINARY in .env, or on PATH). Logo/cover/back/font binaries
# are stubbed since those are proprietary design assets, not test fixtures.
RSpec.describe InvestorMonthlyReportPdfs::Generate do
  PLACEHOLDER_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

  before do
    allow(InvestorMonthlyReportPdfs::Assets).to receive(:data_uri).and_return("data:image/png;base64,#{PLACEHOLDER_PNG}")
    allow(InvestorMonthlyReportPdfs::Assets).to receive(:font_data_uri).and_return("data:font/ttf;base64,#{PLACEHOLDER_PNG}")
  end

  let!(:admin) do
    User.create!(email: 'admin-generate@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'generate-1')
  end

  let!(:investor_missing) do
    inv = Investor.create!(email: 'missing@example.com', name: 'Missing Report', status: 'ACTIVE')
    Portfolio.create!(investor: inv, current_balance: 1000, total_invested: 1000)
    inv
  end

  let!(:investor_with_report) do
    inv = Investor.create!(email: 'has-report@example.com', name: 'Has Report', status: 'ACTIVE')
    Portfolio.create!(investor: inv, current_balance: 2000, total_invested: 2000)
    InvestorMonthlyReportPdf.create!(
      investor: inv,
      month: '2026-05',
      original_filename: 'old.pdf',
      content_type: 'application/pdf',
      byte_size: 8,
      pdf_data: '%PDF-old'
    )
    inv
  end

  let!(:inactive_investor) do
    inv = Investor.create!(email: 'inactive-gen@example.com', name: 'Inactive', status: 'INACTIVE')
    Portfolio.create!(investor: inv, current_balance: 500, total_invested: 500)
    inv
  end

  describe '.call for all active investors' do
    it 'generates for investors missing a report and skips investors that already have one' do
      result = described_class.call(month: '2026-05', generated_by: admin)

      expect(result.generated.map { |r| r.investor_id }).to contain_exactly(investor_missing.id)
      expect(result.skipped).to contain_exactly(investor_with_report)
      expect(result.failed).to be_empty

      record = InvestorMonthlyReportPdf.find_by(investor: investor_missing, month: '2026-05')
      expect(record).to be_present
      expect(record.pdf_data.byteslice(0, 4)).to eq('%PDF')
      expect(record.content_type).to eq('application/pdf')
      expect(record.uploaded_by).to eq(admin)

      expect(InvestorMonthlyReportPdf.find_by(investor: inactive_investor, month: '2026-05')).to be_nil
      expect(InvestorMonthlyReportPdf.find_by(investor: investor_with_report, month: '2026-05').pdf_data).to eq('%PDF-old')
    end

    it 'regenerates every active investor when overwrite is true' do
      result = described_class.call(month: '2026-05', overwrite: true, generated_by: admin)

      expect(result.generated.map(&:investor_id)).to contain_exactly(investor_missing.id, investor_with_report.id)
      expect(InvestorMonthlyReportPdf.find_by(investor: investor_with_report, month: '2026-05').pdf_data).not_to eq('%PDF-old')
    end
  end

  describe '.call for a single investor' do
    it 'generates (and overwrites) only the given investor even without overwrite: true' do
      result = described_class.call(month: '2026-05', investor: investor_with_report, generated_by: admin)

      expect(result.generated.map(&:investor_id)).to contain_exactly(investor_with_report.id)
      expect(InvestorMonthlyReportPdf.find_by(investor: investor_with_report, month: '2026-05').pdf_data).not_to eq('%PDF-old')
      expect(InvestorMonthlyReportPdf.find_by(investor: investor_missing, month: '2026-05')).to be_nil
    end
  end

  it 'returns nil for an invalid month' do
    expect(described_class.call(month: 'not-a-month', generated_by: admin)).to be_nil
  end
end
