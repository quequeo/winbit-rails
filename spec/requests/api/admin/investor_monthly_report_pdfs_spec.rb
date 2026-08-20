# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin investor monthly report PDFs', type: :request do
  let!(:admin) do
    User.create!(email: 'pdfs-admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'pdfs-admin')
  end
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }
  let!(:inactive) { Investor.create!(email: 'old@test.com', name: 'Inactivo', status: 'INACTIVE') }

  before { login_as(admin, scope: :user) }
  after { logout(:user) }

  def uploaded_pdf(filename, body = '%PDF-1.4 x')
    tempfile = Tempfile.new([ File.basename(filename, '.pdf'), '.pdf' ])
    tempfile.binmode
    tempfile.write(body)
    tempfile.rewind
    uploaded = Rack::Test::UploadedFile.new(tempfile.path, 'application/pdf', true, original_filename: filename)
    tempfile.close
    uploaded
  end

  describe 'GET /api/admin/v1/monthly_report_pdfs' do
    it 'lists who has a PDF and who is missing for a month' do
      InvestorMonthlyReportPdf.create!(
        investor: tulio,
        month: '2026-07',
        original_filename: 'Reporte julio - TULIO CAPPARELLI.pdf',
        content_type: 'application/pdf',
        byte_size: 12,
        pdf_data: '%PDF-1.4 hi',
        uploaded_by: admin
      )

      get '/api/admin/v1/monthly_report_pdfs', params: { month: '2026-07' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'month')).to eq('2026-07')
      expect(json.dig('data', 'present').length).to eq(1)
      expect(json.dig('data', 'present').first.dig('investor', 'email')).to eq('tulio@test.com')
      expect(json.dig('data', 'missing').map { |row| row['email'] }).to include('old@test.com')
      expect(json.dig('data', 'counts', 'present')).to eq(1)
    end

    it 'returns 422 without month' do
      get '/api/admin/v1/monthly_report_pdfs'
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST /api/admin/v1/monthly_report_pdfs/bulk' do
    it 'previews matches without persisting when preview=true' do
      post '/api/admin/v1/monthly_report_pdfs/bulk',
           params: {
             month: '2026-07',
             preview: true,
             files: [ uploaded_pdf('Reporte julio - TULIO CAPPARELLI.pdf', '%PDF-1.4 preview') ]
           }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'preview')).to be(true)
      expect(json.dig('data', 'assignments').first['status']).to eq('assign')
      expect(json.dig('data', 'assignments').first.dig('investor', 'email')).to eq('tulio@test.com')
      expect(InvestorMonthlyReportPdf.count).to eq(0)
    end

    it 'uploads by filename name match when confirm=true' do
      post '/api/admin/v1/monthly_report_pdfs/bulk',
           params: {
             month: '2026-07',
             confirm: true,
             files: [ uploaded_pdf('Reporte julio - TULIO CAPPARELLI.pdf', '%PDF-1.4 bulk') ]
           }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'preview')).to be(false)
      expect(json.dig('data', 'uploaded_count')).to eq(1)
      expect(InvestorMonthlyReportPdf.find_by(investor: tulio, month: '2026-07').pdf_data).to eq('%PDF-1.4 bulk')
    end

    it 'assigns a single PDF to an investor id even if the filename does not match' do
      post '/api/admin/v1/monthly_report_pdfs/bulk',
           params: {
             month: '2026-07',
             investor_id: tulio.id,
             files: [ uploaded_pdf('archivo-raro.pdf', '%PDF-1.4 direct') ]
           }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'replaced')).to be(false)
      expect(json.dig('data', 'report', 'investor', 'id')).to eq(tulio.id)
      expect(InvestorMonthlyReportPdf.find_by(investor: tulio, month: '2026-07').pdf_data).to eq('%PDF-1.4 direct')
    end
  end

  describe 'GET /api/admin/v1/monthly_report_pdfs/:id/file' do
    it 'streams the PDF' do
      report = InvestorMonthlyReportPdf.create!(
        investor: tulio,
        month: '2026-07',
        original_filename: 'Reporte julio - TULIO CAPPARELLI.pdf',
        content_type: 'application/pdf',
        byte_size: 12,
        pdf_data: '%PDF-1.4 hi'
      )

      get "/api/admin/v1/monthly_report_pdfs/#{report.id}/file"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
      expect(response.body).to eq('%PDF-1.4 hi')
    end
  end

  describe 'DELETE /api/admin/v1/monthly_report_pdfs/:id' do
    it 'removes the PDF' do
      report = InvestorMonthlyReportPdf.create!(
        investor: tulio,
        month: '2026-07',
        original_filename: 'Reporte julio - TULIO CAPPARELLI.pdf',
        content_type: 'application/pdf',
        byte_size: 12,
        pdf_data: '%PDF-1.4 hi'
      )

      delete "/api/admin/v1/monthly_report_pdfs/#{report.id}"

      expect(response).to have_http_status(:no_content)
      expect(InvestorMonthlyReportPdf.exists?(report.id)).to be(false)
    end
  end
end
