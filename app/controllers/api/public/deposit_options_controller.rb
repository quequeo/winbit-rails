module Api
  module Public
    class DepositOptionsController < BaseController
      # GET /api/public/deposit_options
      def index
        options = DepositOption.active.ordered

        render json: {
          data: options.map { |o| PublicDepositOptionSerializer.new(o).as_json }
        }
      end
    end
  end
end
