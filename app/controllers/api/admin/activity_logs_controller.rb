module Api
  module Admin
    class ActivityLogsController < BaseController
      def index
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 50).to_i
        per_page = [per_page, 100].min # Max 100 per page

        # Base query with eager loading
        logs = ActivityLog.includes(:user, :target).recent

        # Filters
        logs = logs.by_user(params[:user_id]) if params[:user_id].present?
        logs = logs.by_action(params[:action]) if params[:action].present?

        # Pagination
        total = logs.count
        logs = logs.offset((page - 1) * per_page).limit(per_page)

        render json: {
          data: {
            logs: logs.map do |log|
              {
                id: log.id,
                action: log.action,
                action_description: log.action_description,
                user: {
                  id: log.user.id,
                  name: log.user.name,
                  email: log.user.email
                },
                target: {
                  type: log.target_type,
                  id: log.target_id,
                  display: target_display(log)
                },
                metadata: log.metadata,
                created_at: log.created_at
              }
            end,
            pagination: {
              page: page,
              per_page: per_page,
              total: total,
              total_pages: (total.to_f / per_page).ceil
            }
          }
        }
      end

      private

      def target_display(log)
        case log.target_type
        when 'Investor'
          log.target&.name || "Inversor ##{log.target_id}"
        when 'Portfolio'
          investor = log.target&.investor
          investor ? "Portfolio de #{investor.name}" : "Portfolio ##{log.target_id}"
        when 'InvestorRequest'
          req = log.target
          if req
            "#{req.request_type} - $#{req.amount}"
          else
            "Solicitud ##{log.target_id}"
          end
        when 'User'
          log.target&.name || "Admin ##{log.target_id}"
        when 'AppSetting'
          log.target&.key || "Setting ##{log.target_id}"
        else
          "#{log.target_type} ##{log.target_id}"
        end
      end
    end
  end
end
