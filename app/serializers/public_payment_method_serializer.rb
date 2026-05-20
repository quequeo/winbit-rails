class PublicPaymentMethodSerializer
  def initialize(payment_method)
    @payment_method = payment_method
  end

  def as_json(*)
    {
      code: payment_method.code,
      name: payment_method.name,
      kind: payment_method.kind,
      requiresNetwork: payment_method.requires_network,
      requiresLemontag: payment_method.requires_lemontag,
      requiresWalletAddress: payment_method.code == 'CRYPTO',
    }
  end

  private

  attr_reader :payment_method
end
