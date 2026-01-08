module Api
  module Public
    class WalletsController < BaseController
      def index
        wallets = Wallet.where(enabled: true).order(:asset, :network)

        render json: {
          data: wallets.map { |w|
            {
              id: w.id,
              asset: w.asset,
              network: w.network,
              address: w.address,
              enabled: w.enabled,
              createdAt: w.created_at,
              updatedAt: w.updated_at,
            }
          },
        }
      end
    end
  end
end
