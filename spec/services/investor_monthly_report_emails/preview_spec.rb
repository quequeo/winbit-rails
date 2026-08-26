# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportEmails::Preview do
  let!(:investor) { Investor.create!(email: 'ana@example.com', name: 'Ana Pérez', status: 'ACTIVE') }

  before do
    Portfolio.create!(investor: investor, current_balance: 6484)
    InvestorMonthlyReportPdf.create!(
      investor: investor,
      month: '2026-04',
      original_filename: 'Reporte abril - ANA PEREZ.pdf',
      content_type: 'application/pdf',
      byte_size: 12,
      pdf_data: '%PDF-1.4 hi'
    )
    InvestorMonthlyAnnexRow.create!(
      investor: investor,
      month: Date.new(2026, 4, 1),
      return_percent: 2.5,
      return_usd: 158.5,
      portfolio_value: 6484,
      source: 'spreadsheet'
    )
  end

  it 'renders {{nombre}} as the full investor name like campaigns' do
    result = described_class.call(
      month: '2026-04',
      subject: 'Hola {{nombre}}',
      body: "Ganancia {{ganancia_usd}}\nMes {{mes}}"
    )

    expect(result.audience_count).to eq(1)
    expect(result.sample_subject).to eq('Hola Ana Pérez')
    expect(result.sample_body_html).to include('Ana Pérez').or include('$158,50')
    expect(result.recipients.first[:name]).to eq('Ana Pérez')
    expect(result.recipients.first[:has_pdf]).to be(true)
    expect(result.recipients.first[:pdf_filename]).to eq('Reporte abril 2026 - ANA PÉREZ.pdf')
  end
end
