class AdminInvestorDetailSerializer
  def initialize(investor)
    @investor = investor
  end

  def as_json(*)
    {
      id: investor.id,
      email: investor.email,
      name: investor.name,
      status: investor.status,
      portfolio: investor.portfolio,
      portfolioHistory: investor.portfolio_histories.order(date: :desc).limit(10),
      requests: investor.investor_requests.order(requested_at: :desc).limit(10)
    }
  end

  private

  attr_reader :investor
end
