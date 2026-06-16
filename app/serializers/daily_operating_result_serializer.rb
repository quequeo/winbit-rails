class DailyOperatingResultSerializer
  def initialize(result, amount_usd: nil)
    @result = result
    @amount_usd = amount_usd
  end

  def as_json(*)
    {
      id: result.id,
      date: result.date,
      percent: result.percent.to_f,
      amount_usd: resolved_amount_usd,
      notes: result.notes,
      applied_at: result.applied_at,
      applied_by: {
        id: result.applied_by_id,
        email: result.applied_by&.email,
        name: result.applied_by&.name
      },
      created_at: result.created_at
    }
  end

  private

  attr_reader :result

  def resolved_amount_usd
    return @amount_usd.to_f if @amount_usd

    DailyOperatingUsdTotals.for_date(result.date)
  end
end
