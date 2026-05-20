module Api
  module Public
    class PaymentMethodsController < BaseController
      # GET /api/public/payment_methods?flow=withdrawal|deposit
      def index
        flow = params[:flow].presence || 'withdrawal'
        unless PaymentMethod::FLOWS.include?(flow)
          return render_error('Invalid flow. Use deposit or withdrawal', status: :bad_request)
        end

        methods = PaymentMethod.for_flow(flow)

        render json: {
          data: methods.map { |m| PublicPaymentMethodSerializer.new(m).as_json }
        }
      end
    end
  end
end
