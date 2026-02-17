module Api
  module Public
    class DepositOptionsController < BaseController
      # GET /api/public/deposit_options
      def index
        options = DepositOption.active.ordered

        render json: {
          data: options.map { |o|
            {
              id: o.id,
              category: o.category,
              label: o.label,
              currency: o.currency,
              details: o.details,
              position: o.position,
            }
          },
        }
      end
    end
  end
end
