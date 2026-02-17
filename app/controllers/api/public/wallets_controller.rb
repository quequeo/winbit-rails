module Api
  module Public
    class WalletsController < BaseController
      def index
        wallets = Wallet.where(enabled: true).order(:asset, :network)

        render json: {
          data: wallets.map { |w| PublicWalletSerializer.new(w).as_json }
        }
      end
    end
  end
end
