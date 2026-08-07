module Api
  module Admin
    class OperationDayCapturesController < BaseController
      before_action :require_superadmin!, only: [:create]
      before_action :set_capture, only: [:show, :image]

      def index
        if params[:date].present?
          date = parse_date(params[:date])
          return render_error('Fecha inválida') unless date

          records = OperationDayCapture.for_date(date).ordered
          return render json: {
            data: records.map { |capture| OperationDayCaptureSerializer.new(capture).as_json },
          }
        end

        from_date = parse_date(params[:from]) if params[:from].present?
        to_date = parse_date(params[:to]) if params[:to].present?
        scope = OperationDayCapture.all
        scope = scope.where(capture_date: from_date..) if from_date
        scope = scope.where(capture_date: ..to_date) if to_date

        counts = scope.group(:capture_date).order(:capture_date).count
        render json: {
          data: counts.map { |date, count| { date: date.strftime('%Y-%m-%d'), count: count } },
        }
      end

      def show
        render json: { data: OperationDayCaptureSerializer.new(@capture).as_json }
      end

      def image
        expires_in 1.hour, public: false
        send_data @capture.image_data,
                  type: @capture.content_type,
                  disposition: 'inline',
                  filename: @capture.original_filename
      end

      def create
        file = params[:file] || params[:image]
        return render_error('Archivo requerido') if file.blank?

        filename = file.respond_to?(:original_filename) ? file.original_filename : params[:original_filename].to_s
        return render_error('Nombre de archivo requerido') if filename.blank?

        if OperationDayCapture.exists?(original_filename: File.basename(filename))
          return render json: { error: 'Ya existe una captura con ese nombre' }, status: :conflict
        end

        parsed = OperationDayCaptures::FilenameParser.parse(filename)
        return render_error("No se pudo interpretar el archivo: #{parsed.skip_reason}") unless parsed.ok

        unless StrategyOperation.exists?(operation_date: parsed.capture_date)
          return render_error('No hay operación de estrategia para esa fecha')
        end

        bytes = file.respond_to?(:read) ? file.read : file
        admin_label = StrategyOperation
          .where(operation_date: parsed.capture_date, asset: parsed.asset)
          .where.not(result_label: [nil, ''])
          .order(:created_at)
          .limit(1)
          .pick(:result_label)
        token = parsed.filename_result.to_s.strip.upcase
        result_label =
          if StrategyOperation::RESULT_LABELS.include?(admin_label.to_s)
            admin_label
          elsif StrategyOperation::RESULT_LABELS.include?(token)
            token
          end

        capture = OperationDayCapture.create!(
          capture_date: parsed.capture_date,
          asset: parsed.asset,
          result_label: result_label,
          original_filename: File.basename(filename),
          content_type: file.respond_to?(:content_type) ? (file.content_type.presence || 'image/png') : 'image/png',
          byte_size: bytes.bytesize,
          image_data: bytes,
          created_by: current_user,
        )

        render json: { data: OperationDayCaptureSerializer.new(capture).as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: 'Validación fallida', details: e.record.errors.to_hash }, status: :unprocessable_content
      end

      private

      def set_capture
        @capture = OperationDayCapture.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Captura no encontrada' }, status: :not_found
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError, Date::Error
        nil
      end
    end
  end
end
