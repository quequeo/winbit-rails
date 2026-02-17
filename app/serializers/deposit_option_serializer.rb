class DepositOptionSerializer
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
      active: option.active,
      position: option.position,
      createdAt: option.created_at,
      updatedAt: option.updated_at
    }
  end

  private

  attr_reader :option
end
