class PublicDepositOptionSerializer
  def initialize(option)
    @option = option
  end

  def as_json(*)
    {
      id: option.id,
      category: option.category,
      label: option.label,
      currency: option.currency,
      details: option.details,
      position: option.position
    }
  end

  private

  attr_reader :option
end
