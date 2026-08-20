# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::DirectoryImporter do
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }

  it 'imports PDFs from a directory and ignores non-PDF files' do
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, 'Reporte julio - TULIO CAPPARELLI.pdf'), '%PDF-1.4 tulio')
      File.binwrite(File.join(dir, 'notes.txt'), 'ignore me')
      File.binwrite(File.join(dir, '.hidden.pdf'), '%PDF-1.4 hidden')

      uploader = described_class.new(dir: dir, month: '2026-07').call

      expect(uploader.summary[:uploaded_count]).to eq(1)
      expect(InvestorMonthlyReportPdf.find_by(investor: tulio, month: '2026-07').pdf_data).to eq('%PDF-1.4 tulio')
    end
  end

  it 'applies email overrides when importing from disk' do
    miriam = Investor.create!(email: 'miri.ana@hotmail.com', name: 'Miriam Ana', status: 'ACTIVE')

    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, 'Reporte julio - MIRIAM.pdf'), '%PDF-1.4 miriam')

      uploader = described_class.new(
        dir: dir,
        month: '2026-07',
        email_overrides: { 'Reporte julio - MIRIAM.pdf' => 'miri.ana@hotmail.com' }
      ).call

      expect(uploader.summary[:uploaded_count]).to eq(1)
      expect(InvestorMonthlyReportPdf.find_by(investor: miriam, month: '2026-07')).to be_present
    end
  end

  it 'does not persist in preview mode' do
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, 'Reporte julio - TULIO CAPPARELLI.pdf'), '%PDF-1.4 tulio')

      uploader = described_class.new(dir: dir, month: '2026-07', preview: true).call

      expect(uploader.summary[:preview]).to be(true)
      expect(uploader.summary[:uploaded_count]).to eq(0)
      expect(InvestorMonthlyReportPdf.count).to eq(0)
    end
  end
end
