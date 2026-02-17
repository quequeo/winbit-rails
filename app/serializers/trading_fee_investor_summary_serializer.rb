class TradingFeeInvestorSummarySerializer
  def initialize(investor:, period_start:, period_end:, profit_amount:, monthly_profits:, existing_fee:)
    @investor = investor
    @period_start = period_start
    @period_end = period_end
    @profit_amount = profit_amount
    @monthly_profits = monthly_profits
    @existing_fee = existing_fee
  end

  def as_json(*)
    {
      investor_id: investor.id,
      investor_name: investor.name,
      investor_email: investor.email,
      trading_fee_frequency: investor.trading_fee_frequency,
      investor_trading_fee_percentage: investor.trading_fee_percentage.to_f,
      current_balance: investor.portfolio&.current_balance || 0,
      period_start: period_start,
      period_end: period_end,
      profit_amount: profit_amount,
      has_profit: profit_amount > 0,
      already_applied: existing_fee.present?,
      applied_fee_id: existing_fee&.id,
      applied_fee_amount: existing_fee&.fee_amount&.to_f,
      applied_fee_percentage: existing_fee&.fee_percentage&.to_f,
      monthly_profits: monthly_profits
    }
  end

  private

  attr_reader :investor, :period_start, :period_end, :profit_amount, :monthly_profits, :existing_fee
end
