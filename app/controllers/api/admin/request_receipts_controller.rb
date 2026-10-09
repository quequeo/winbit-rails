module Api
  module Admin
    class RequestReceiptsController < BaseController
      def show
        request_record = find_record!(
          model: InvestorRequest,
          id: params[:id],
          message: 'Solicitud no encontrada'
        )
        return unless request_record

        unless request_record.status == 'APPROVED'
          return render_error('El comprobante solo está disponible para solicitudes aprobadas', status: :unprocessable_entity)
        end

        receipt = request_record.receipt_pdf || RequestReceiptPdfs::Generate.call(request: request_record)

        send_data receipt.pdf_data,
                  type: receipt.content_type,
                  disposition: 'attachment',
                  filename: receipt.original_filename
      rescue StandardError => e
        render_error(e.message, status: :bad_request)
      end
    end
  end
end
