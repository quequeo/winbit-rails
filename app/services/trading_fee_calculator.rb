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

  def frequency
    investor.respond_to?(:trading_fee_frequency) ? investor.trading_fee_frequency : "QUARTERLY"
  end

  def annual?
    frequency == "ANNUAL"
  end

  def monthly?
    frequency == "MONTHLY"
  end

  def semestral?
    frequency == "SEMESTRAL"
  end

  # MONTHLY: último mes calendario cerrado.
  # Ej: si hoy es 21/01/2026 -> 01/12/2025..31/12/2025
  def last_completed_month_start
    (reference_date.beginning_of_month - 1.month).beginning_of_month.to_date
  end

  def last_completed_month_end
    (reference_date.beginning_of_month - 1.day).to_date
  end

  # QUARTERLY: último trimestre cerrado.
  # Ej: si hoy es 21/01/2026 -> 01/10/2025..31/12/2025
  def last_completed_quarter_start
    (reference_date.beginning_of_quarter - 3.months).beginning_of_quarter.to_date
  end

  def last_completed_quarter_end
    (reference_date.beginning_of_quarter - 1.day).to_date
  end

  # SEMESTRAL: último semestre cerrado.
  # Semestres: Ene-Jun y Jul-Dic.
  # Ej: si hoy es 21/01/2026 -> 01/07/2025..31/12/2025
  # Ej: si hoy es 15/08/2026 -> 01/01/2026..30/06/2026
  def last_completed_semester_start
    if reference_date.month <= 6
      Date.new(reference_date.year - 1, 7, 1)
    else
      Date.new(reference_date.year, 1, 1)
    end
  end

  def last_completed_semester_end
    if reference_date.month <= 6
      Date.new(reference_date.year - 1, 12, 31)
    else
      Date.new(reference_date.year, 6, 30)
    end
  end

  # ANNUAL: último año calendario cerrado.
  # Ej: si hoy es 21/01/2026 -> 01/01/2025..31/12/2025
  def last_completed_year_start
    Date.new(reference_date.year - 1, 1, 1)
  end

  def last_completed_year_end
    Date.new(reference_date.year - 1, 12, 31)
  end

  def default_period_start
    if monthly?
      last_completed_month_start
    elsif annual?
      last_completed_year_start
    elsif semestral?
      last_completed_semester_start
    else
      last_completed_quarter_start
    end
  end

  def default_period_end
    if monthly?
      last_completed_month_end
    elsif annual?
      last_completed_year_end
    elsif semestral?
      last_completed_semester_end
    else
      last_completed_quarter_end
    end
  end

  # Para mostrar el período en UI:
  # - si ya existe un fee para ese período (según frecuencia), mostramos ese período (period_start..period_end)
  # - si no, mostramos el período por defecto
  def period_start
    @period_start ||= begin
      fee = last_fee_for(default_period_start, default_period_end)
      fee ? fee.period_start : default_period_start
    end
  end

  def period_end
    @period_end ||= begin
      fee = last_fee_for(default_period_start, default_period_end)
      fee ? fee.period_end : default_period_end
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
