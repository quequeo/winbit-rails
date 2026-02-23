class TradingFeeApplicator
  attr_reader :investor, :fee_percentage, :applied_by, :notes, :errors

  def initialize(investor, fee_percentage:, applied_by:, notes: nil, period_start: nil, period_end: nil)
    @investor = investor
    @fee_percentage = fee_percentage.to_f
    @applied_by = applied_by
    @notes = notes
    @errors = []
    @period_start_override = period_start
    @period_end_override = period_end
  end

  def apply
    validate_inputs
    return false if errors.any?

    if @period_start_override.present? && @period_end_override.present?
      @period_start = @period_start_override.to_date
      @period_end = @period_end_override.to_date

      validate_period_for_investor
      return false if errors.any?

      @profit_amount = PortfolioHistory.where(investor_id: investor.id, event: 'OPERATING_RESULT', status: 'COMPLETED')
                                     .where(date: @period_start.beginning_of_day..@period_end.end_of_day)
                                     .sum(:amount)
                                     .to_f
    else
      calculator = TradingFeeCalculator.new(investor)
      calculation = calculator.calculate

      @profit_amount = calculation[:profit_amount]
      @period_start = calculation[:period_start]
      @period_end = calculation[:period_end]
    end

    if TradingFee.exists?(investor_id: investor.id, period_start: @period_start, period_end: @period_end)
      @errors << 'Trading fee ya aplicado para este período'
      return false
    end

    validate_profit
    return false if errors.any?

    ApplicationRecord.transaction do
      create_trading_fee
      create_portfolio_history
      update_portfolio_balance
    end

    true
  rescue StandardError => e
    @errors << "Error applying trading fee: #{e.message}"
    Rails.logger.error("TradingFeeApplicator Error: #{e.message}\n#{e.backtrace.join("\n")}")
    false
  end

  def fee_amount
    @fee_amount ||= (@profit_amount * (@fee_percentage / 100.0)).round(2)
  end

  private

  def validate_inputs
    if investor.blank?
      @errors << 'Investor is required'
    elsif !investor.status_active?
      @errors << 'Investor must be active'
    end

    if fee_percentage <= 0 || fee_percentage > 100
      @errors << 'Fee percentage must be between 0 and 100'
    end

    @errors << 'Applied by user is required' if applied_by.blank?
  end

  # Guardrail: valida que el período coincida con la frecuencia del inversor.
  def validate_period_for_investor
    return if @period_start.blank? || @period_end.blank?
    return unless investor.respond_to?(:trading_fee_frequency)

    freq = investor.trading_fee_frequency

    if freq == 'MONTHLY'
      expected_start = @period_start.beginning_of_month.to_date
      expected_end = @period_start.end_of_month.to_date

      if @period_start != expected_start || @period_end != expected_end
        @errors << 'Este inversor está configurado como MONTHLY: el período debe ser un mes calendario completo'
      end
    elsif freq == 'ANNUAL'
      expected_start = @period_start.beginning_of_year.to_date
      expected_end = @period_start.end_of_year.to_date

      if @period_start != expected_start || @period_end != expected_end
        @errors << 'Este inversor está configurado como ANNUAL: el período debe ser un año calendario completo'
      end
    elsif freq == 'SEMESTRAL'
      valid_semesters = [
        [Date.new(@period_start.year, 1, 1), Date.new(@period_start.year, 6, 30)],
        [Date.new(@period_start.year, 7, 1), Date.new(@period_start.year, 12, 31)]
      ]

      unless valid_semesters.any? { |s, e| @period_start == s && @period_end == e }
        @errors << 'Este inversor está configurado como SEMESTRAL: el período debe ser un semestre completo (Ene-Jun o Jul-Dic)'
      end
    elsif freq == 'QUARTERLY'
      expected_start = @period_start.beginning_of_quarter.to_date
      expected_end = @period_start.end_of_quarter.to_date

      if @period_start != expected_start || @period_end != expected_end
        @errors << 'Este inversor está configurado como QUARTERLY: el período debe ser un trimestre completo'
      end
    end
  end

  def validate_profit
    if @profit_amount <= 0
      @errors << "No profit in the period (#{@period_start} to #{@period_end})"
    end
  end

  def create_trading_fee
    @trading_fee = TradingFee.create!(
      investor: investor,
      applied_by: applied_by,
      period_start: @period_start,
      period_end: @period_end,
      profit_amount: @profit_amount,
      fee_percentage: fee_percentage,
      fee_amount: fee_amount,
      source: 'PERIODIC',
      notes: notes,
      applied_at: Time.current
    )
  end

  def create_portfolio_history
    portfolio = investor.portfolio

    PortfolioHistory.create!(
      investor: investor,
      event: 'TRADING_FEE',
      amount: -fee_amount, # Negativo porque es un cargo
      previous_balance: portfolio.current_balance,
      new_balance: portfolio.current_balance - fee_amount,
      status: 'COMPLETED',
      date: Time.current
    )
  end

  def update_portfolio_balance
    portfolio = investor.portfolio
    new_balance = portfolio.current_balance - fee_amount

    if new_balance < 0
      raise StandardError, 'Insufficient balance to apply trading fee'
    end

    portfolio.update!(current_balance: new_balance)
  end

  # No notifications for trading fee application (explicitly disabled).
  def send_notification
    nil
  end
end
