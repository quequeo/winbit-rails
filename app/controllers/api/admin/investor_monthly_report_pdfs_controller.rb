# frozen_string_literal: true

module Api
  module Admin
    class InvestorMonthlyReportPdfsController < BaseController
      before_action :set_record, only: [ :file, :destroy ]

      def index
        month = parse_month_param(required: true)
        return if performed?

        reports = InvestorMonthlyReportPdf.for_month(month).without_pdf_data.includes(:investor)
        reports_by_investor_id = reports.index_by(&:investor_id)
        investors = Investor.order(:name)

        present = []
        missing = []

        investors.each do |investor|
          report = reports_by_investor_id[investor.id]
          if report
            present << InvestorMonthlyReportPdfSerializer.new(report).as_json
          else
            missing << {
              id: investor.id,
              name: investor.name,
              email: investor.email,
              status: investor.status
            }
          end
        end

        render json: {
          data: {
            month: month,
            present: present,
            missing: missing,
            counts: {
              present: present.size,
              missing: missing.size,
              missingActive: missing.count { |row| row[:status] == 'ACTIVE' }
            }
          }
        }
      end

      def bulk
        month = parse_month_param(required: true)
        return if performed?

        uploads = extract_uploads
        if uploads.empty?
          return render_error('Archivo requerido. Subí PDFs o un ZIP.', status: :unprocessable_content)
        end

        if params[:investor_id].present?
          return assign_to_investor(month: month, uploads: uploads)
        end

        uploader = InvestorMonthlyReportPdfs::BulkUploader.new(
          month: month,
          uploads: uploads,
          uploaded_by: current_user,
          preview: preview_requested?
        )
        uploader.call

        render json: { data: uploader.summary }, status: :ok
      end

      def generate
        month = parse_month_param(required: true)
        return if performed?

        investor = nil
        if params[:investor_id].present?
          investor = find_investor_by_id(id: params[:investor_id])
          return unless investor
        end

        result = InvestorMonthlyReportPdfs::Generate.call(
          month: month,
          investor: investor,
          overwrite: boolean_param(params[:overwrite]),
          generated_by: current_user
        )

        render json: { data: result.as_json }, status: :ok
      rescue StandardError => e
        Rails.logger.error("[InvestorMonthlyReportPdfsController#generate] #{e.class}: #{e.message}")
        render_error('No se pudo generar el reporte. Verificá que wkhtmltopdf esté instalado.', status: :internal_server_error)
      end

      def file
        send_data @record.pdf_data,
                  type: @record.content_type,
                  disposition: 'attachment',
                  filename: @record.download_filename
      end

      def destroy
        @record.destroy!
        head :no_content
      end

      private

      def set_record
        @record = InvestorMonthlyReportPdf.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Reporte no encontrado' }, status: :not_found
      end

      def preview_requested?
        if params.key?(:preview)
          return boolean_param(params[:preview])
        end
        if params.key?(:confirm)
          return !boolean_param(params[:confirm])
        end

        true
      end

      def boolean_param(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def parse_month_param(required: false)
        raw = params[:month].presence
        if raw.blank?
          return render_error('Mes requerido (YYYY-MM)', status: :unprocessable_content) if required

          return InvestorMonthlyReportPdf.last_closed_month
        end

        parsed = InvestorMonthlyReportPdfs::Month.parse(raw)
        return parsed if parsed

        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
        nil
      end

      def assign_to_investor(month:, uploads:)
        if uploads.size != 1
          return render_error('Para asignar a un inversor subí un solo PDF', status: :unprocessable_content)
        end

        investor = find_investor_by_id(id: params[:investor_id])
        return unless investor

        upload = uploads.first
        unless upload.filename.downcase.end_with?('.pdf') &&
               upload.bytes.byteslice(0, 4).to_s.start_with?(InvestorMonthlyReportPdf::PDF_MAGIC)
          return render_error('El archivo debe ser un PDF', status: :unprocessable_content)
        end

        if upload.bytes.bytesize > InvestorMonthlyReportPdf::MAX_BYTES
          return render_error("El PDF supera #{InvestorMonthlyReportPdf::MAX_BYTES / 1.megabyte}MB", status: :unprocessable_content)
        end

        record = InvestorMonthlyReportPdf.find_or_initialize_by(investor: investor, month: month)
        replaced = record.persisted?
        record.assign_attributes(
          original_filename: upload.filename,
          content_type: 'application/pdf',
          byte_size: upload.bytes.bytesize,
          pdf_data: upload.bytes,
          uploaded_by: current_user
        )
        record.save!

        payload = InvestorMonthlyReportPdfSerializer.new(record).as_json
        render json: { data: { replaced: replaced, report: payload } }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: 'Validación fallida', details: e.record.errors.to_hash }, status: :unprocessable_content
      end

      def extract_uploads
        files = Array(params[:files]).compact
        files += Array(params[:file]).compact
        files += Array(params[:'files[]']).compact

        files.filter_map do |file|
          next unless file.respond_to?(:read)

          filename = file.respond_to?(:original_filename) ? file.original_filename : nil
          next if filename.blank?

          bytes = file.read
          file.rewind if file.respond_to?(:rewind)
          InvestorMonthlyReportPdfs::Upload.new(filename: filename, bytes: bytes)
        end
      end
    end
  end
end
