# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe InvestorMonthlyReportPdfs::BulkUploader do
  let!(:admin) do
    User.create!(email: 'pdf-admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'pdf-admin')
  end
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }

  def upload(filename, body = '%PDF-1.4 x')
    InvestorMonthlyReportPdfs::Upload.new(filename: filename, bytes: body)
  end

    it 'assigns a PDF by investor name and replaces on the same month' do
      uploader = described_class.new(
        month: '2026-07',
        uploads: [upload('Reporte julio - TULIO CAPPARELLI.pdf', '%PDF-1.4 first')],
        uploaded_by: admin
      )
      uploader.call
      expect(uploader.summary[:uploaded_count]).to eq(1)
      expect(InvestorMonthlyReportPdf.find_by(investor: tulio, month: '2026-07').pdf_data).to eq('%PDF-1.4 first')

      again = described_class.new(
        month: '2026-07',
        uploads: [upload('Reporte julio - TULIO CAPPARELLI.pdf', '%PDF-1.4 second')],
        uploaded_by: admin
      )
      again.call
      expect(again.summary[:replaced_count]).to eq(1)
      expect(InvestorMonthlyReportPdf.where(investor: tulio, month: '2026-07').count).to eq(1)
      expect(InvestorMonthlyReportPdf.find_by(investor: tulio, month: '2026-07').pdf_data).to eq('%PDF-1.4 second')
    end

    it 'previews matches without writing to the database' do
      uploader = described_class.new(
        month: '2026-07',
        uploads: [upload('Reporte julio - TULIO CAPPARELLI.pdf', '%PDF-1.4 preview')],
        uploaded_by: admin,
        preview: true
      )
      uploader.call

      expect(InvestorMonthlyReportPdf.count).to eq(0)
      expect(uploader.summary[:preview]).to be(true)
      expect(uploader.summary[:uploaded_count]).to eq(0)
      assignment = uploader.summary[:assignments].first
      expect(assignment[:status]).to eq('assign')
      expect(assignment[:parsedName]).to eq('TULIO CAPPARELLI')
      expect(assignment.dig(:investor, :email)).to eq('tulio@test.com')
    end

  it 'skips files whose month does not match the selected month' do
    uploader = described_class.new(
      month: '2026-07',
      uploads: [upload('Reporte agosto - TULIO CAPPARELLI.pdf')],
      uploaded_by: admin
    )
    uploader.call
    expect(uploader.summary[:skip_breakdown]).to be_nil
    expect(uploader.summary[:skipped].first[:reason]).to eq('month_mismatch')
    expect(InvestorMonthlyReportPdf.count).to eq(0)
  end

  it 'skips unknown names' do
    uploader = described_class.new(
      month: '2026-07',
      uploads: [upload('Reporte julio - FULANO DE TAL.pdf')],
      uploaded_by: admin
    )
    uploader.call
    expect(uploader.summary[:skipped].first[:reason]).to eq('investor_not_found')
  end

  it 'extracts PDFs from a zip' do
    zip_io = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry('Reporte julio - TULIO CAPPARELLI.pdf')
      zos.write('%PDF-1.4 zip')
    end

    uploader = described_class.new(
      month: '2026-07',
      uploads: [upload('reportes.zip', zip_io.string)],
      uploaded_by: admin
    )
    uploader.call
    expect(uploader.summary[:uploaded_count]).to eq(1)
    expect(InvestorMonthlyReportPdf.find_by(investor: tulio, month: '2026-07').pdf_data).to eq('%PDF-1.4 zip')
  end

  it 'assigns by email override when the same name would be ambiguous' do
    jaime = Investor.create!(email: 'jaimegarciamendez@gmail.com', name: 'Jaime García Méndez', status: 'ACTIVE')
    Investor.create!(email: 'monitoapps@gmail.com', name: 'Jaime García Méndez', status: 'ACTIVE')

    uploader = described_class.new(
      month: '2026-07',
      uploads: [upload('Reporte julio - JAIME GARCÍA MÉNDEZ.pdf', '%PDF-1.4 jaime')],
      email_overrides: {
        'Reporte julio - JAIME GARCÍA MÉNDEZ.pdf' => 'jaimegarciamendez@gmail.com'
      }
    )
    uploader.call

    expect(uploader.summary[:uploaded_count]).to eq(1)
    report = InvestorMonthlyReportPdf.find_by(month: '2026-07', investor: jaime)
    expect(report).to be_present
    expect(InvestorMonthlyReportPdf.joins(:investor).where(month: '2026-07', investors: { email: 'monitoapps@gmail.com' })).to be_empty
  end

  it 'assigns by email override when the filename name does not match the DB name' do
    gustavo = Investor.create!(email: 'gustavooscarzuccotti@gmail.com', name: 'Gustavo Zuccotti', status: 'ACTIVE')

    uploader = described_class.new(
      month: '2026-07',
      uploads: [upload('Reporte julio - GUSTAVO OSCAR ZUCCOTTI.pdf', '%PDF-1.4 gustavo')],
      email_overrides: {
        'Reporte julio - GUSTAVO OSCAR ZUCCOTTI.pdf' => 'gustavooscarzuccotti@gmail.com'
      }
    )
    uploader.call

    expect(uploader.summary[:uploaded_count]).to eq(1)
    expect(InvestorMonthlyReportPdf.find_by(investor: gustavo, month: '2026-07')).to be_present
  end

  it 'skips override emails that do not exist' do
    uploader = described_class.new(
      month: '2026-07',
      uploads: [upload('Reporte julio - MIRIAM.pdf')],
      email_overrides: { 'Reporte julio - MIRIAM.pdf' => 'missing@test.com' }
    )
    uploader.call

    expect(uploader.summary[:skipped].first[:reason]).to eq('override_investor_not_found')
    expect(InvestorMonthlyReportPdf.count).to eq(0)
  end
end
