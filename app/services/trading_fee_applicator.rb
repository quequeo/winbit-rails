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
