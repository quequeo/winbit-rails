# frozen_string_literal: true

require 'digest'

module InvestorMonthlyReportPdfs
  # Huella de los datos con los que se arma el reporte de un inversor para un
  # mes. Se guarda al generar el PDF; si después cambia (una comisión o un
  # movimiento cargado con fecha de ese mes, una operación corregida, un
  # movimiento borrado), el PDF quedó desactualizado.
  #
  # Usa conteos y sumas en vez de fechas de modificación porque
  # portfolio_histories no tiene updated_at y así también se detecta lo que
  # se borra.
  class DataSignature
    # Se sube cada vez que cambia la forma de calcular o mostrar el reporte
    # (no solo sus datos), para que los PDFs ya generados queden marcados
    # como desactualizados y "Generar todos" los rehaga.
    # 2: rendimiento mensual neto del costo del servicio.
    CALCULATION_VERSION = 2

    def self.for_investors(month:, investor_ids:)
      new(month:).for_investors(investor_ids)
    end

    def initialize(month:)
      @month_start = Date.strptime("#{month}-01", '%Y-%m-%d')
      @month_end = @month_start.end_of_month
    end

    def for_investors(investor_ids)
      ids = Array(investor_ids).uniq
      return {} if ids.empty?

      histories = PortfolioHistory
        .where(investor_id: ids, status: 'COMPLETED')
        .where('date <= ?', @month_end.in_time_zone.end_of_day)
        .group(:investor_id)
        .pluck(:investor_id, Arel.sql('COUNT(*)'), Arel.sql('SUM(amount)'), Arel.sql('SUM(new_balance)'))
        .to_h { |id, *values| [ id, values ] }

      annex_rows = InvestorMonthlyAnnexRow
        .where(investor_id: ids)
        .where('month <= ?', @month_start)
        .group(:investor_id)
        .pluck(:investor_id, Arel.sql('COUNT(*)'), Arel.sql('MAX(updated_at)'))
        .to_h { |id, *values| [ id, values ] }

      shared = month_wide_values

      ids.index_with do |id|
        digest([ CALCULATION_VERSION, histories[id], annex_rows[id], shared ])
      end
    end

    private

    # Lo que es igual para todos los inversores: las operaciones del mes
    # (hoja de operaciones) y los resultados diarios (rendimiento de Winbit).
    def month_wide_values
      trades = StrategyOperation
        .where(operation_date: @month_start..@month_end)
        .pick(Arel.sql('COUNT(*)'), Arel.sql('SUM(result_usd)'), Arel.sql('MAX(updated_at)'))
      daily = DailyOperatingResult
        .where(date: @month_start..@month_end)
        .pick(Arel.sql('COUNT(*)'), Arel.sql('SUM(percent)'), Arel.sql('MAX(updated_at)'))
      [ trades, daily ]
    end

    def digest(values)
      normalized = values.flatten.map { |v| v.respond_to?(:utc) ? v.utc.iso8601(6) : v.to_s }
      Digest::SHA256.hexdigest(normalized.join('|'))[0, 32]
    end
  end
end
