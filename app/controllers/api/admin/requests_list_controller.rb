module Api
  module Admin
    class RequestsListController < BaseController
      def index
        status = params[:status]
        type = params[:type]

        scope = InvestorRequest.includes(:investor).order(requested_at: :desc)
        scope = scope.where(status: status) if status.present?
        scope = scope.where(request_type: type) if type.present?

        # Pagination (default: all records up to 200 per page)
        page = [params[:page].to_i, 1].max
        raw_per_page = params[:per_page].to_i
        per_page = raw_per_page.positive? ? raw_per_page.clamp(1, 200) : 200

        total = scope.count
        paginated = scope.offset((page - 1) * per_page).limit(per_page)

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
            pagination: {
              page: page,
              per_page: per_page,
              total: total,
              total_pages: (total.to_f / per_page).ceil,
            },
          },
        }
      end
    end
  end
end
