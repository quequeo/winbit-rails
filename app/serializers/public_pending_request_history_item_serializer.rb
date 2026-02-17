class PublicPendingRequestHistoryItemSerializer
  def initialize(request)
    @request = request
  end

  def as_json(*)
    {
      id: "request_#{request.id}",
      investorId: request.investor_id,
      date: request.requested_at,
      event: request.request_type,
      amount: request.amount.to_f,
      previousBalance: nil,
      newBalance: nil,
      status: request.status,
      createdAt: request.requested_at,
      method: request.method,
      network: request.network,
      notes: request.notes
    }
  end

  private

  attr_reader :request
end
