class TradingFeeInvestorSummarySerializer
  def initialize(investor:, period_start:, period_end:, profit_amount:, monthly_profits:, existing_fee:, canonical_period_start: nil, withdrawal_fee_info: nil)
    @investor = investor
    @period_start = period_start
    @period_end = period_end
    @canonical_period_start = canonical_period_start
    @profit_amount = profit_amount
    @monthly_profits = monthly_profits
    @existing_fee = existing_fee
    @withdrawal_fee_info = withdrawal_fee_info
  end

  def as_json(*)
    result = {
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

    result[:period_clipped] = canonical_period_start.present? &&
                               period_start.to_date != canonical_period_start.to_date

    if withdrawal_fee_info.present?
      result[:withdrawal_fee_in_period] = withdrawal_fee_info
    end

    result
  end

  private

  attr_reader :investor, :period_start, :period_end, :canonical_period_start, :profit_amount, :monthly_profits, :existing_fee, :withdrawal_fee_info
end
