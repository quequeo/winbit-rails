module Public
  class StrategyOperationHistoryEnrichment
    def self.index_by_date_for(investor)
      dates = investor.portfolio_histories
                      .where(event: 'OPERATING_RESULT')
                      .pluck(:date)
                      .map(&:to_date)
                      .uniq
      return {} if dates.empty?

      StrategyOperation.where(operation_date: dates).index_by(&:operation_date)
    end

    def self.extra_fields(operation)
      return {} unless operation

      {
        asset: operation.asset,
        contract: operation.asset,
        direction: operation.direction,
        openedAt: operation.opened_at,
        closedAt: operation.closed_at,
        entryPrice: operation.entry_price&.to_f,
        exitPrice: operation.exit_price&.to_f,
        ratio: operation.ratio&.to_f,
        timeframe: operation.timeframe,
        resultLabel: operation.result_label,
      }.compact
    end
  end
end
