class DailyOperatingResultByMonthItemSerializer
  def initialize(result, amount_usd: nil)
    @result = result
    @amount_usd = amount_usd
  end

  def as_json(*)
    {
      id: result.id,
      date: result.date,
      percent: result.percent.to_f,
      amount_usd: @amount_usd.nil? ? DailyOperatingUsdTotals.for_date(result.date) : @amount_usd.to_f,
      notes: result.notes
    }
  end

  private

  attr_reader :result
end
