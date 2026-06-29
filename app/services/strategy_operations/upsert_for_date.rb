module StrategyOperations
  class UpsertForDate
    def initialize(date:, created_by:, params:, result_usd: nil)
      @date = date.to_date
      @created_by = created_by
      @params = params&.to_h&.symbolize_keys || {}
      @result_usd = result_usd
    end

    def call
      if @params.blank? || @params[:asset].blank?
        StrategyOperation.where(operation_date: @date).delete_all
        return true
      end

      unless StrategyOperation::ASSETS.include?(@params[:asset].to_s.strip.upcase)
        @error = 'Activo inválido. Permitidos: MNQ, MBT, MYM, MES'
        return false
      end

      result_label = presence(@params[:result_label])
      if result_label.present? && StrategyOperation::RESULT_LABELS.exclude?(result_label)
        @error = 'Resultado inválido. Permitidos: POSITIVO, NEGATIVO, BE+, BE-'
        return false
      end

      opened_at = normalize_time(@params[:opened_at])
      closed_at = normalize_time(@params[:closed_at])
      if opened_at.nil? || closed_at.nil?
        @error = 'Apertura y cierre son obligatorias en formato HH:MM (ej: 12:08)'
        return false
      end

      ApplicationRecord.transaction do
        StrategyOperation.where(operation_date: @date).delete_all
        StrategyOperation.create!(attributes(opened_at:, closed_at:, result_label:).merge(
          operation_date: @date,
          created_by: @created_by,
          source: 'manual',
          result_usd: resolved_result_usd,
        ))
      end

      true
    rescue ActiveRecord::RecordInvalid => e
      @error = e.record.errors.full_messages.join(', ')
      false
    end

    attr_reader :error

    private

    def attributes(opened_at:, closed_at:, result_label:)
      {
        asset: @params[:asset].to_s.strip.upcase,
        timeframe: presence(@params[:timeframe]),
        direction: presence(@params[:direction]),
        result_label: result_label,
        ratio: decimal(@params[:ratio]),
        opened_at: opened_at,
        closed_at: closed_at,
        notes: presence(@params[:notes]),
      }
    end

    def resolved_result_usd
      return @result_usd.to_f if @result_usd.present?

      DailyOperatingUsdTotals.for_date(@date)
    end

    def normalize_time(value)
      text = value.to_s.strip
      return text if StrategyOperation.valid_time?(text)

      nil
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
