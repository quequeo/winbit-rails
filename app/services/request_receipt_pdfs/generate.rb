# frozen_string_literal: true

module RequestReceiptPdfs
  # Renders the deposit/withdrawal receipt (A4 landscape, Winbit style) for an
  # APPROVED request through Grover/Chrome headless and stores it in
  # RequestReceiptPdf, replacing any previous one for that request.
  class Generate
    def self.call(request:, balance_after: nil)
      new(request:, balance_after:).call
    end

    # Winbit_Comprobante_Retiro_R-2026-0142.pdf
    def self.filename_for(request, data = DocumentData.call(request: request))
      reference = data[:operation_number].presence ||
                  (request.processed_at || Time.current).in_time_zone(DocumentData::ZONE).strftime('%Y%m%d')
      "Winbit_Comprobante_#{data[:file_kind]}_#{reference}.pdf"
    end

    def initialize(request:, balance_after: nil)
      @request = request
      @balance_after = balance_after
    end

    def call
      raise StandardError, 'Solo se genera comprobante para solicitudes aprobadas' unless @request.status == 'APPROVED'

      data = DocumentData.call(request: @request, balance_after: @balance_after)
      bytes = render_pdf(data)
      record = RequestReceiptPdf.find_or_initialize_by(request_id: @request.id)
      record.assign_attributes(
        original_filename: self.class.filename_for(@request, data),
        content_type: 'application/pdf',
        byte_size: bytes.bytesize,
        pdf_data: bytes
      )
      record.save!
      record
    end

    private

    def render_pdf(data)
      InvestorMonthlyReportPdfs::EnsureChromeInstalled.call
      html = ActionController::Base.renderer.render(
        template: 'request_receipt_pdfs/document',
        layout: false,
        locals: { data: data }
      )
      InvestorMonthlyReportPdfs::Generate::RENDER_MUTEX.synchronize { Grover.new(html).to_pdf }
    end
  end
end
