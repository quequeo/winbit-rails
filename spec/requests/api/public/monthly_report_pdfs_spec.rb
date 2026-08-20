# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public monthly report PDFs', type: :request do
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }
  let!(:other) { Investor.create!(email: 'otro@test.com', name: 'Otro Inversor', status: 'ACTIVE') }
  let!(:inactive) { Investor.create!(email: 'old@test.com', name: 'Inactivo', status: 'INACTIVE') }

  def create_pdf!(investor, month, body)
    InvestorMonthlyReportPdf.create!(
      investor: investor,
      month: month,
      original_filename: "Reporte #{month} - #{investor.name}.pdf",
      content_type: 'application/pdf',
      byte_size: body.bytesize,
      pdf_data: body
    )
  end

  it 'streams the logged investor PDF for an explicit month' do
    create_pdf!(tulio, '2026-07', '%PDF-1.4 tulio')
    create_pdf!(other, '2026-07', '%PDF-1.4 other')

    get "/api/public/v1/investor/#{CGI.escape(tulio.email)}/monthly_report", params: { month: '2026-07' }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/pdf')
    expect(response.body).to eq('%PDF-1.4 tulio')
    expect(response.body).not_to include('other')
  end

  it 'defaults to the last closed calendar month' do
    create_pdf!(tulio, '2026-07', '%PDF-1.4 july')
    create_pdf!(tulio, '2026-08', '%PDF-1.4 august')

    travel_to Time.zone.local(2026, 8, 20, 15, 0, 0) do
      get "/api/public/v1/investor/#{CGI.escape(tulio.email)}/monthly_report"

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('%PDF-1.4 july')
    end
  end

  it 'returns 404 when that month has no PDF' do
    get "/api/public/v1/investor/#{CGI.escape(tulio.email)}/monthly_report", params: { month: '2026-07' }

    expect(response).to have_http_status(:not_found)
    json = JSON.parse(response.body)
    expect(json['error']).to eq('Reporte no encontrado')
  end

  it 'returns 403 for inactive investors' do
    create_pdf!(inactive, '2026-07', '%PDF-1.4 old')

    get "/api/public/v1/investor/#{CGI.escape(inactive.email)}/monthly_report", params: { month: '2026-07' }

    expect(response).to have_http_status(:forbidden)
  end

  it 'returns 404 for unknown investors' do
    get "/api/public/v1/investor/#{CGI.escape('missing@test.com')}/monthly_report"

    expect(response).to have_http_status(:not_found)
  end

  it 'never returns another investor PDF' do
    create_pdf!(other, '2026-07', '%PDF-1.4 secret')

    get "/api/public/v1/investor/#{CGI.escape(tulio.email)}/monthly_report", params: { month: '2026-07' }

    expect(response).to have_http_status(:not_found)
  end
end
