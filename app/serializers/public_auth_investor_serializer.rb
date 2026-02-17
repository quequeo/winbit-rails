class PublicAuthInvestorSerializer
  def initialize(investor)
    @investor = investor
  end

  def as_json(*)
    {
      email: investor.email,
      name: investor.name,
      status: investor.status
    }
  end

  private

  attr_reader :investor
end
