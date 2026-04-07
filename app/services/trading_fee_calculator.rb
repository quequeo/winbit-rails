class TradingFeeCalculator
  attr_reader :investor, :reference_date

  def initialize(investor, reference_date: nil)
    @investor = investor
    @reference_date = reference_date || inferred_reference_date
  end

  def calculate
    {
      profit_amount: profit_amount,
      period_start: period_start,
      period_end: period_end
    }
  end

  # Returns [adjusted_start, adjusted_end] when a withdrawal fee in the period
  # already charged profit. The periodic fee should only charge from the day after.
  def self.adjust_period_for_withdrawal_fees(investor, period_start, period_end)
    return [period_start.to_date, period_end.to_date] if period_start.blank? || period_end.blank?

    start_d = period_start.to_date
    end_d = period_end.to_date

    last_wd = investor.trading_fees
                      .where(source: 'WITHDRAWAL')
                      .where(voided_at: nil)
                      .where('applied_at::date >= ? AND applied_at::date <= ?', start_d, end_d)
                      .order(applied_at: :desc)
                      .first

    return [start_d, end_d] if last_wd.blank?

    day_after = last_wd.applied_at.to_date + 1.day
    # Period fully consumed: withdrawal on last day (or later). Use empty future range.
    return [end_d + 1.day, end_d + 2.days] if day_after > end_d

    [day_after, end_d]
  end

  private

  def inferred_reference_date
    latest_operating_date = PortfolioHistory
                            .where(investor_id: investor.id, event: 'OPERATING_RESULT', status: 'COMPLETED')
                            .maximum(:date)
                            &.to_date

    return Date.current unless latest_operating_date

    months_buffer =
      case frequency
      when 'MONTHLY' then 1
      when 'QUARTERLY' then 3
      when 'SEMESTRAL' then 6
      when 'ANNUAL' then 12
      else 3
      end

    inferred = latest_operating_date.advance(months: months_buffer)
    [inferred, Date.current].min
  end

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

  def effective_period_start
    @effective_period_start ||= self.class.adjust_period_for_withdrawal_fees(
      investor, default_period_start, default_period_end
    ).first
  end

  def effective_period_end
    @effective_period_end ||= self.class.adjust_period_for_withdrawal_fees(
      investor, default_period_start, default_period_end
    ).last
  end

  # Para mostrar el período en UI:
  # - si ya existe un fee que solapa con el período efectivo, mostramos ese
  # - si no, mostramos el período efectivo (ajustado por fees por retiro)
  def period_start
    @period_start ||= begin
      fee = last_periodic_fee_overlapping(effective_period_start, effective_period_end)
      fee ? fee.period_start : effective_period_start
    end
  end

  def period_end
    @period_end ||= begin
      fee = last_periodic_fee_overlapping(effective_period_start, effective_period_end)
      fee ? fee.period_end : effective_period_end
    end
  end

  def profit_amount
    @profit_amount ||= begin
      return 0.0 if effective_period_start >= effective_period_end

      range = effective_period_start.beginning_of_day..effective_period_end.end_of_day

      PortfolioHistory.where(investor_id: investor.id)
                     .where(event: 'OPERATING_RESULT')
                     .where(status: 'COMPLETED')
                     .where(date: range)
                     .sum(:amount)
                     .to_f
    end
  end

  def last_periodic_fee_overlapping(start_date, end_date)
    investor.trading_fees
            .active
            .where(source: 'PERIODIC')
            .where('period_start <= ? AND period_end >= ?', end_date, start_date)
            .order(applied_at: :desc)
            .first
  end

  def last_fee_for(start_date, end_date)
    investor.trading_fees
            .where(period_start: start_date, period_end: end_date)
            .order(applied_at: :desc)
            .first
  end
end
