class PublicWalletSerializer
  def initialize(wallet)
    @wallet = wallet
  end

  def as_json(*)
    {
      id: wallet.id,
      asset: wallet.asset,
      network: wallet.network,
      address: wallet.address,
      enabled: wallet.enabled,
      createdAt: wallet.created_at,
      updatedAt: wallet.updated_at
    }
  end

  private

  attr_reader :wallet
end
