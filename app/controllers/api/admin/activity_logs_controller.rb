module Api
  module Admin
    class ActivityLogsController < BaseController
      def index
        # Base query with eager loading (polymorphic, so we preload broadly)
        logs = ActivityLog.includes(:user).preload(:target).recent

        # Filters
        logs = logs.by_user(params[:user_id]) if params[:user_id].present?
        logs = logs.by_action(params[:filter_action]) if params[:filter_action].present?

        paginated_result = paginate(logs, default_per_page: 50, max_per_page: 100)
        logs = paginated_result[:records]

        logs_data = logs.map { |log| ActivityLogSerializer.new(log).as_json }

        render json: {
          data: {
            logs: logs_data,
            pagination: paginated_result[:pagination]
          }
        }
      end
    end
  end
end
