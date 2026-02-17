module Api
  module Admin
    class RequestsListController < BaseController
      def index
        status = params[:status]
        type = params[:type]

        scope = InvestorRequest.includes(:investor).order(requested_at: :desc)
        scope = scope.where(status: status) if status.present?
        scope = scope.where(request_type: type) if type.present?

        paginated_result = paginate(scope, default_per_page: 200, max_per_page: 200)
        paginated = paginated_result[:records]

        data = paginated.map do |r|
          {
            id: r.id,
            investorId: r.investor_id,
            type: r.request_type,
            amount: r.amount.to_f,
            method: r.method,
            status: r.status,
            attachmentUrl: r.attachment_url,
            requestedAt: r.requested_at,
            processedAt: r.processed_at,
            investor: {
              name: r.investor.name,
              email: r.investor.email,
            },
          }
        end

        pending_count = InvestorRequest.where(status: 'PENDING').count

        render json: {
          data: {
            requests: data,
            pendingCount: pending_count,
            pagination: paginated_result[:pagination],
          },
        }
      end
    end
  end
end
