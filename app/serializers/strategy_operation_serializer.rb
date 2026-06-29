class StrategyOperationSerializer
  def initialize(operation)
    @operation = operation
  end

  def as_json(*)
    {
      id: operation.id,
      operationDate: operation.operation_date.strftime('%Y-%m-%d'),
      asset: operation.asset,
      timeframe: operation.timeframe,
      direction: operation.direction,
      resultLabel: operation.result_label,
      resultUsd: operation.result_usd&.to_f,
      ratio: operation.ratio&.to_f,
      openedAt: time_or_nil(operation.opened_at),
      closedAt: time_or_nil(operation.closed_at),
      notes: operation.notes,
      source: operation.source,
      createdBy: operation.created_by&.name,
      createdAt: operation.created_at,
      updatedAt: operation.updated_at,
    }
  end

  private

  attr_reader :operation

  def time_or_nil(value)
    text = value.to_s.strip
    return nil if text.blank?
    return text if StrategyOperation.valid_time?(text)

    nil
  end
end
