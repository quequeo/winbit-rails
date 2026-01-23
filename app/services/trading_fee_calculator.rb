class TradingFeeCalculator
  attr_reader :investor, :reference_date

  def initialize(investor, reference_date: Date.current)
    @investor = investor
    @reference_date = reference_date
  end

  def calculate
    {
      profit_amount: profit_amount,
      period_start: period_start,
      period_end: period_end
    }
  end

  private

  # El período por defecto es el último trimestre cerrado.
  # Ej: si hoy es 21/01/2026 -> último trimestre cerrado = 01/10/2025..31/12/2025
  def last_completed_quarter_start
    (reference_date.beginning_of_quarter - 3.months).beginning_of_quarter.to_date
  end

  def last_completed_quarter_end
    (reference_date.beginning_of_quarter - 1.day).to_date
  end

  # Para mostrar el período en UI:
  # - si ya existe un fee para ese trimestre, mostramos ese período (period_start..period_end)
  # - si no, mostramos el último trimestre cerrado
  def period_start
    @period_start ||= begin
      fee = last_fee_for(last_completed_quarter_start, last_completed_quarter_end)
      fee ? fee.period_start : last_completed_quarter_start
    end
  end

  def period_end
    @period_end ||= begin
      fee = last_fee_for(last_completed_quarter_start, last_completed_quarter_end)
      fee ? fee.period_end : last_completed_quarter_end
    end
  end

  def profit_amount
    @profit_amount ||= begin
      range = period_start.to_date.beginning_of_day..period_end.to_date.end_of_day

      PortfolioHistory.where(investor_id: investor.id)
                     .where(event: 'OPERATING_RESULT')
                     .where(status: 'COMPLETED')
                     .where(date: range)
                     .sum(:amount)
                     .to_f
    end
  end

  def last_fee_for(start_date, end_date)
    investor.trading_fees
            .where(period_start: start_date, period_end: end_date)
            .order(applied_at: :desc)
            .first
  end
end
