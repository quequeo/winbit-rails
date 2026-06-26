module StrategyOperations
  class UpsertForDate
    def initialize(date:, created_by:, params:)
      @date = date.to_date
      @created_by = created_by
      @params = params&.to_h&.symbolize_keys || {}
    end

    def call
      if @params.blank? || @params[:asset].blank?
        StrategyOperation.where(operation_date: @date).delete_all
        return true
      end

      ApplicationRecord.transaction do
        StrategyOperation.where(operation_date: @date).delete_all
        StrategyOperation.create!(attributes.merge(
          operation_date: @date,
          created_by: @created_by,
          source: 'manual',
        ))
      end

      true
    rescue ActiveRecord::RecordInvalid => e
      @error = e.record.errors.full_messages.join(', ')
      false
    end

    attr_reader :error

    private

    def attributes
      {
        asset: @params[:asset].to_s.strip,
        timeframe: presence(@params[:timeframe]),
        direction: presence(@params[:direction]),
        result_label: presence(@params[:result_label]),
        result_usd: decimal(@params[:result_usd]),
        ratio: decimal(@params[:ratio]),
        opened_at: presence(@params[:opened_at]),
        closed_at: presence(@params[:closed_at]),
        notes: presence(@params[:notes]),
      }
    end

    def presence(value)
      text = value.to_s.strip
      text.presence
    end

    def decimal(value)
      return nil if value.blank?

      BigDecimal(value.to_s.tr(',', '.'))
    rescue ArgumentError
      nil
    end
  end
end
