class DailyOperatingResultSerializer
  def initialize(result)
    @result = result
  end

  def as_json(*)
    {
      id: result.id,
      date: result.date,
      percent: result.percent.to_f,
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
end
