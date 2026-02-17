class DailyOperatingResultByMonthItemSerializer
  def initialize(result)
    @result = result
  end

  def as_json(*)
    {
      id: result.id,
      date: result.date,
      percent: result.percent.to_f
    }
  end

  private

  attr_reader :result
end
