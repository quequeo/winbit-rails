class PublicPortfolioHistoryItemSerializer
  def initialize(history, extra: {})
    @history = history
    @extra = extra
  end

  def as_json(*)
    {
      id: history.id,
      investorId: history.investor_id,
      date: history.date,
      event: history.event,
      amount: history.amount.to_f,
      previousBalance: history.previous_balance.to_f,
      newBalance: history.new_balance.to_f,
      status: history.status,
      createdAt: history.created_at
    }.merge(extra)
  end

  private

  attr_reader :history, :extra
end
