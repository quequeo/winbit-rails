class TradingFeeSerializer
  def initialize(fee)
    @fee = fee
  end

  def as_json(*)
    {
      id: fee.id,
      investor_id: fee.investor_id,
      investor_name: fee.investor.name,
      investor_email: fee.investor.email,
      applied_by_id: fee.applied_by_id,
      applied_by_name: fee.applied_by.name,
      period_start: fee.period_start,
      period_end: fee.period_end,
      profit_amount: fee.profit_amount,
      fee_percentage: fee.fee_percentage.to_f,
      fee_amount: fee.fee_amount,
      source: fee.source,
      withdrawal_amount: fee.withdrawal_amount,
      withdrawal_request_id: fee.withdrawal_request_id,
      notes: fee.notes,
      applied_at: fee.applied_at,
      voided_at: fee.voided_at,
      voided_by_id: fee.voided_by_id,
      created_at: fee.created_at
    }
  end

  private

  attr_reader :fee
end
