module Api
  module Admin
    class ActivityLogsController < BaseController
      def index
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 50).to_i
        per_page = [per_page, 100].min # Max 100 per page

        # Base query with eager loading (polymorphic, so we preload broadly)
        logs = ActivityLog.includes(:user).preload(:target).recent

        # Filters
        logs = logs.by_user(params[:user_id]) if params[:user_id].present?
        logs = logs.by_action(params[:filter_action]) if params[:filter_action].present?

        # Pagination
        total = logs.count
        logs = logs.offset((page - 1) * per_page).limit(per_page)

        logs_data = logs.map do |log|
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
        end

        render json: {
          data: {
            logs: logs_data,
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
        when 'TradingFee'
          fee = log.target
          if fee
            "#{fee.investor&.name} — $#{fee.fee_amount}"
          else
            "Trading fee ##{log.target_id}"
          end
        when 'DepositOption'
          option = log.target
          if option
            "#{option.category}: #{option.label}"
          else
            "Opción de depósito ##{log.target_id}"
          end
        when 'User'
          log.target&.name || "Admin ##{log.target_id}"
        when 'AppSetting'
          setting = log.target
          if setting
            case setting.key
            when 'investor_notifications_enabled'
              'Notificaciones a Inversores (Habilitado/Deshabilitado)'
            when 'investor_email_whitelist'
              'Lista Blanca de Emails de Inversores'
            else
              setting.description || setting.key
            end
          else
            "Configuración ##{log.target_id}"
          end
        else
          "#{log.target_type} ##{log.target_id}"
        end
      end
    end
  end
end
