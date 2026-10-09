# frozen_string_literal: true

module RequestReceiptPdfs
  # Renders the deposit/withdrawal receipt (A4 landscape, Winbit style) for an
  # APPROVED request through Grover/Chrome headless and stores it in
  # RequestReceiptPdf, replacing any previous one for that request.
  class Generate
    def self.call(request:, balance_after: nil)
      new(request:, balance_after:).call
    end

    def initialize(request:, balance_after: nil)
      @request = request
      @balance_after = balance_after
    end

    def call
      raise StandardError, 'Solo se genera comprobante para solicitudes aprobadas' unless @request.status == 'APPROVED'

      bytes = render_pdf
      record = RequestReceiptPdf.find_or_initialize_by(request_id: @request.id)
      record.assign_attributes(
        original_filename: filename,
        content_type: 'application/pdf',
        byte_size: bytes.bytesize,
        pdf_data: bytes
      )
      record.save!
      record
    end

    private

    def filename
      kind = @request.request_type == 'WITHDRAWAL' ? 'Comprobante de retiro' : 'Comprobante de aporte'
      date = (@request.processed_at || Time.current).in_time_zone.strftime('%Y-%m-%d')
      name = @request.investor.name.to_s.gsub(%r{[\/]}, ' ').squish
      "#{kind} #{date} - #{name}.pdf"
    end

    def render_pdf
      InvestorMonthlyReportPdfs::EnsureChromeInstalled.call
      data = DocumentData.call(request: @request, balance_after: @balance_after)
      html = ActionController::Base.renderer.render(
        template: 'request_receipt_pdfs/document',
        layout: false,
        locals: { data: data }
      )
      InvestorMonthlyReportPdfs::Generate::RENDER_MUTEX.synchronize { Grover.new(html).to_pdf }
    end
  end
end
