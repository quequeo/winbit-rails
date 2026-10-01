# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Renders the monthly report PDF (DocumentData + document.html.erb, via
  # Grover/Chrome headless) and saves it into InvestorMonthlyReportPdf - the
  # same table InvestorMonthlyReportPdfs::BulkUploader writes to when an
  # admin uploads a PDF by hand. Because it's the same table, the existing
  # email campaign feature (EmailCampaigns::Send, MonthlyReportEmailPanel)
  # works with generated PDFs with zero changes.
  #
  # Usage:
  #   InvestorMonthlyReportPdfs::Generate.call(month: '2026-07', generated_by: current_user)
  #     -> generates for every ACTIVE investor missing a report for that month
  #
  #   InvestorMonthlyReportPdfs::Generate.call(month: '2026-07', investor: some_investor, generated_by: current_user)
  #     -> generates (and overwrites, if one already exists) for a single investor
  #
  #   InvestorMonthlyReportPdfs::Generate.call(month: '2026-07', overwrite: true, generated_by: current_user)
  #     -> regenerates for every ACTIVE investor, replacing any existing report
  class Generate
    # Each render launches a full Chrome process - on the 512MB dyno this
    # app runs on, two or three running at once is enough to exhaust memory
    # and take the whole app down (confirmed in production: a double-click
    # on "Generar todos" ran two GenerateAllJob instances concurrently,
    # each launching Chrome per investor, and the dyno OOMed - R14, then
    # every request including investor login started timing out). This
    # mutex caps the dyno to one Chrome process at a time, across every
    # caller (the bulk job, a single "Generar" click, overlapping bulk
    # runs) - slower, but it can't pile up.
    RENDER_MUTEX = Mutex.new

    Result = Struct.new(:month, :generated, :skipped, :failed, keyword_init: true) do
      def as_json(*)
        {
          month: month,
          generated: generated.map { |r| InvestorMonthlyReportPdfSerializer.new(r).as_json },
          skipped: skipped.map { |i| { investorId: i.id, name: i.name } },
          failed: failed.map { |f| { investorId: f[:investor].id, name: f[:investor].name, error: f[:error] } },
        }
      end
    end

    def self.call(month:, investor: nil, overwrite: false, generated_by: nil)
      new(month:, investor:, overwrite:, generated_by:).call
    end

    def initialize(month:, investor: nil, overwrite: false, generated_by: nil)
      @month = InvestorMonthlyReportPdfs::Month.parse(month)
      @investor = investor
      @overwrite = overwrite
      @generated_by = generated_by
    end

    def call
      return nil unless @month

      generated = []
      skipped = []
      failed = []

      target_investors.each do |investor|
        existing = InvestorMonthlyReportPdf.find_by(investor: investor, month: @month)

        if existing && !@overwrite && @investor.nil?
          skipped << investor
          next
        end

        begin
          generated << generate_for(investor, existing)
        rescue StandardError => e
          Rails.logger.error(
            "[InvestorMonthlyReportPdfs::Generate] investor=#{investor.id} month=#{@month}: #{e.class}: #{e.message}"
          )
          failed << { investor: investor, error: e.message }
        end
      end

      Result.new(month: @month, generated: generated, skipped: skipped, failed: failed)
    end

    private

    def target_investors
      return [@investor] if @investor

      Investor.where(status: 'ACTIVE').order(:name)
    end

    def generate_for(investor, existing)
      pdf_bytes = render_pdf(investor)
      record = existing || InvestorMonthlyReportPdf.new(investor: investor, month: @month)
      record.assign_attributes(
        original_filename: "Reporte #{@month} - #{investor.name}.pdf",
        content_type: 'application/pdf',
        byte_size: pdf_bytes.bytesize,
        pdf_data: pdf_bytes,
        uploaded_by: @generated_by
      )
      record.save!
      record
    end

    def render_pdf(investor)
      EnsureChromeInstalled.call
      data = DocumentData.call(investor: investor, report_month: @month)
      # ApplicationController is api_only (ActionController::API), whose
      # renderer swallows template errors and returns blank output instead
      # of raising - use ActionController::Base's renderer so a broken
      # template/missing asset fails loudly instead of saving a blank PDF.
      html = ActionController::Base.renderer.render(
        template: 'investor_monthly_report_pdfs/document',
        layout: false,
        locals: { data: data }
      )

      # Page size/margins/print_background/launch_args come from the global
      # Grover.configure block (config/initializers/grover.rb) - the template's
      # own `@page` CSS rule (297mm x 210mm, margin 0) is honored via
      # prefer_css_page_size there.
      RENDER_MUTEX.synchronize { Grover.new(html).to_pdf }
    end
  end
end
