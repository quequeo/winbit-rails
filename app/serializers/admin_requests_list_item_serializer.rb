class AdminRequestsListItemSerializer
  def initialize(request)
    @request = request
  end

  def as_json(*)
    {
      id: request.id,
      investorId: request.investor_id,
      type: request.request_type,
      amount: request.amount.to_f,
      method: request.method,
      status: request.status,
      attachmentUrl: request.attachment_url,
      requestedAt: request.requested_at,
      processedAt: request.processed_at,
      investor: {
        name: request.investor.name,
        email: request.investor.email
      }
    }
  end

  private

  attr_reader :request
end
