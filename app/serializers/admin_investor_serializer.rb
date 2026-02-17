class AdminInvestorSerializer
  def initialize(investor)
    @investor = investor
  end

  def as_json(*)
    {
      id: investor.id,
      email: investor.email,
      name: investor.name,
      status: investor.status,
      tradingFeeFrequency: investor.trading_fee_frequency,
      tradingFeePercentage: investor.trading_fee_percentage.to_f,
      hasPassword: investor.password_digest.present?,
      createdAt: investor.created_at,
      updatedAt: investor.updated_at,
      portfolio: portfolio_payload
    }
  end

  private

  attr_reader :investor

  def portfolio_payload
    return nil unless investor.portfolio

    {
      currentBalance: investor.portfolio.current_balance.to_f,
      totalInvested: investor.portfolio.total_invested.to_f
    }
  end
end
