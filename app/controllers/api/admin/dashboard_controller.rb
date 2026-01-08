module Api
  module Admin
    class DashboardController < BaseController
      def show
        investor_count = Investor.where(status: 'ACTIVE').count
        pending_request_count = InvestorRequest.where(status: 'PENDING').count
        total_aum = Portfolio.sum(:current_balance)

        render json: {
          data: {
            investorCount: investor_count,
            pendingRequestCount: pending_request_count,
            totalAum: total_aum.to_f,
          },
        }
      end
    end
  end
end
