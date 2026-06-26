module StrategyOperations
  class Importer
    attr_reader :errors, :imported_count, :skipped_count, :warnings

    def initialize(path:, created_by:, replace_existing: true)
      @path = path
      @created_by = created_by
      @replace_existing = replace_existing
      @errors = []
      @warnings = []
      @imported_count = 0
      @skipped_count = 0
    end

    def call
      rows = SpreadsheetParser.new(path: path).rows
      if rows.empty?
        errors << 'No se encontraron filas válidas en el Excel'
        return false
      end

      admin_dates = DailyOperatingResult.pluck(:date).to_set
      eligible_rows = rows.select { |row| admin_dates.include?(row.operation_date) }
      skipped_no_admin = rows.size - eligible_rows.size
      if skipped_no_admin.positive?
        warnings << "#{skipped_no_admin} filas omitidas porque no hay operativa diaria en admin para esa fecha"
      end

      selected_rows = eligible_rows
                        .group_by(&:operation_date)
                        .values
                        .map { |day_rows| pick_row_for_day(day_rows) }

      ApplicationRecord.transaction do
        if replace_existing
          dates = selected_rows.map(&:operation_date)
          StrategyOperation.where(operation_date: dates, source: 'import').delete_all
        end

        selected_rows.each do |row|
          StrategyOperation.create!(attributes_for(row))
          @imported_count += 1
        end
      end

      @skipped_count = skipped_no_admin + (eligible_rows.size - selected_rows.size)
      true
    rescue StandardError => e
      errors << e.message
      false
    end

    private

    attr_reader :path, :created_by, :replace_existing

    def pick_row_for_day(day_rows)
      day_rows.max_by do |row|
        usd_score = row.result_usd ? row.result_usd.abs : BigDecimal('0')
        ratio_score = row.ratio ? row.ratio.abs : BigDecimal('0')
        [usd_score, ratio_score]
      end
    end

    def attributes_for(row)
      {
        operation_date: row.operation_date,
        asset: row.asset,
        timeframe: row.timeframe,
        direction: row.direction,
        result_label: row.result_label,
        result_usd: row.result_usd&.to_f,
        ratio: row.ratio&.to_f,
        opened_at: row.opened_at,
        closed_at: row.closed_at,
        notes: row.notes,
        source: 'import',
        created_by: created_by,
      }
    end
  end
end
