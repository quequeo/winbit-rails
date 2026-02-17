class ApplicationController < ActionController::API
  include Paginatable
  include InvestorLookup
  include RecordLookup
  include DateParamParsing

  private

  def render_error(message, status: :bad_request, details: nil)
    payload = { error: message }
    payload[:details] = details if details
    render json: payload, status: status
  end
end
