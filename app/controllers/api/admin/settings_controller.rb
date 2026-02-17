module Api
  module Admin
    class SettingsController < BaseController
      before_action :require_superadmin!, only: [:update]

      # GET /api/admin/settings
      def index
        render json: { data: AdminSettingsSerializer.new.as_json }
      end

      # PATCH /api/admin/settings
      def update
        permitted = params.permit(:investor_notifications_enabled, investor_email_whitelist: [])
        settings_updated = []

        if permitted.key?(:investor_notifications_enabled)
          setting = AppSetting.set(
            'investor_notifications_enabled',
            permitted[:investor_notifications_enabled].to_s,
            description: 'Habilitar/deshabilitar notificaciones por email a inversores'
          )
          settings_updated << setting
        end

        if params.key?(:investor_email_whitelist)
          whitelist = params[:investor_email_whitelist]
          whitelist = whitelist.split(',').map(&:strip) if whitelist.is_a?(String)
          whitelist = Array(whitelist).map(&:strip).reject(&:empty?)
          whitelist = whitelist.select { |e| e.match?(/\A[^@\s]+@[^@\s]+\z/) }

          setting = AppSetting.set(
            'investor_email_whitelist',
            whitelist,
            description: 'Lista de emails de inversores que siempre reciben notificaciones (para testing)'
          )
          settings_updated << setting
        end

        settings_updated.each do |setting|
          metadata = {}

          if setting.key == 'investor_notifications_enabled'
            metadata[:nuevo_valor] = setting.value == 'true' ? 'Habilitado' : 'Deshabilitado'
          elsif setting.key == 'investor_email_whitelist'
            emails = JSON.parse(setting.value) rescue [] # rubocop:disable Style/RescueModifier
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

        render json: { data: AdminSettingsSerializer.new.as_json }
      end
    end
  end
end
