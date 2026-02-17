module InvestorLookup
  extend ActiveSupport::Concern

  private

  def find_investor_by_id(id:, includes: nil, message: 'Inversor no encontrado', status: :not_found)
    scope = includes.present? ? Investor.includes(*Array(includes)) : Investor.all
    investor = scope.find_by(id: id)
    return investor if investor

    render_error(message, status: status)
    nil
  end

  def find_investor_by_email(email:, includes: nil, message: 'Investor not found', status: :not_found)
    scope = includes.present? ? Investor.includes(*Array(includes)) : Investor.all
    investor = scope.find_by(email: email)
    return investor if investor

    render_error(message, status: status)
    nil
  end

  def require_active_investor!(investor, message: 'Investor is not active', status: :forbidden)
    return true if investor&.status_active?

    render_error(message, status: status)
    false
  end
end
