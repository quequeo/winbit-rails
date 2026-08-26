# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportEmails::Audience do
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }
  let!(:jaime) { Investor.create!(email: 'monitoapps@gmail.com', name: 'Jaime Empty', status: 'ACTIVE') }
  let!(:inactive) { Investor.create!(email: 'old@test.com', name: 'Inactivo', status: 'INACTIVE') }
  let!(:missing_pdf) { Investor.create!(email: 'sinpdf@test.com', name: 'Sin Pdf', status: 'ACTIVE') }

  before do
    Portfolio.create!(investor: tulio, current_balance: 5000)
    Portfolio.create!(investor: jaime, current_balance: 0)
    Portfolio.create!(investor: inactive, current_balance: 800)
    Portfolio.create!(investor: missing_pdf, current_balance: 1200)

    InvestorMonthlyReportPdf.create!(
      investor: tulio,
      month: '2026-07',
      original_filename: 'Reporte julio - TULIO CAPPARELLI.pdf',
      content_type: 'application/pdf',
      byte_size: 12,
      pdf_data: '%PDF-1.4 hi'
    )
    InvestorMonthlyReportPdf.create!(
      investor: jaime,
      month: '2026-07',
      original_filename: 'Reporte julio - JAIME.pdf',
      content_type: 'application/pdf',
      byte_size: 12,
      pdf_data: '%PDF-1.4 ja'
    )
    InvestorMonthlyReportPdf.create!(
      investor: inactive,
      month: '2026-07',
      original_filename: 'Reporte julio - INACTIVO.pdf',
      content_type: 'application/pdf',
      byte_size: 12,
      pdf_data: '%PDF-1.4 in'
    )
  end

  it 'only marks ACTIVE investors with PDF and balance > 0 as eligible' do
    result = described_class.call(month: '2026-07')

    expect(result.eligible.map { |row| row.investor.email }).to eq([ 'tulio@test.com' ])
    skipped = result.skipped.index_by { |row| row.investor.email }
    expect(skipped['monitoapps@gmail.com'].skip_reason).to eq('zero_balance')
    expect(skipped['old@test.com'].skip_reason).to eq('inactive')
    expect(skipped['sinpdf@test.com'].skip_reason).to eq('missing_pdf')
  end
end
