module Api
  module Admin
    class SettingsController < BaseController
      # GET /api/admin/settings
      def index
        settings = {
          investor_notifications_enabled: AppSetting.investor_notifications_enabled?,
          investor_email_whitelist: AppSetting.investor_email_whitelist,
        }

        render json: { data: settings }
      end

      # PATCH /api/admin/settings
      def update
        settings_updated = []

        if params.key?(:investor_notifications_enabled)
          setting = AppSetting.set(
            'investor_notifications_enabled',
            params[:investor_notifications_enabled].to_s,
            description: 'Habilitar/deshabilitar notificaciones por email a inversores'
          )
          settings_updated << setting
        end

        if params.key?(:investor_email_whitelist)
          whitelist = params[:investor_email_whitelist]
          whitelist = whitelist.split(',').map(&:strip).reject(&:empty?) if whitelist.is_a?(String)
          whitelist = whitelist.reject(&:empty?) if whitelist.is_a?(Array)

          setting = AppSetting.set(
            'investor_email_whitelist',
            whitelist,
            description: 'Lista de emails de inversores que siempre reciben notificaciones (para testing)'
          )
          settings_updated << setting
        end

        # Log activity for each setting updated
        settings_updated.each do |setting|
          metadata = {}

          if setting.key == 'investor_notifications_enabled'
            metadata[:nuevo_valor] = setting.value == 'true' ? 'Habilitado' : 'Deshabilitado'
          elsif setting.key == 'investor_email_whitelist'
            emails = JSON.parse(setting.value) rescue []
            metadata[:emails] = emails.join(', ')
            metadata[:cantidad] = emails.length
          end

          ActivityLogger.log(
            user: current_user,
            action: 'update_settings',
            target: setting,
            metadata: metadata
          )
        end

        # Return updated settings
        settings = {
          investor_notifications_enabled: AppSetting.investor_notifications_enabled?,
          investor_email_whitelist: AppSetting.investor_email_whitelist,
        }

        render json: { data: settings }
      end
    end
  end
end
