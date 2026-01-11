# Service to control whether notifications should be sent to investors
class NotificationGate
  class << self
    # Determina si se debe enviar una notificación a un inversor
    # @param investor_email [String] Email del inversor
    # @return [Boolean]
    def should_send_to_investor?(investor_email)
      return false if investor_email.blank?

      # Si las notificaciones están globalmente habilitadas, enviar
      return true if AppSetting.investor_notifications_enabled?

      # Si no están habilitadas, solo enviar si está en la whitelist
      in_whitelist?(investor_email)
    end

    # Verifica si un email está en la whitelist
    # @param email [String]
    # @return [Boolean]
    def in_whitelist?(email)
      return false if email.blank?

      whitelist = AppSetting.investor_email_whitelist
      whitelist.include?(email.downcase.strip)
    end

    # Los emails a admins siempre se envían
    # @return [Boolean]
    def should_send_to_admin?
      true
    end

    # Log cuando se bloquea un email (para debugging)
    def log_blocked_notification(investor_email, notification_type)
      Rails.logger.info(
        "[NotificationGate] Blocked #{notification_type} notification to #{investor_email}. " \
        "Notifications enabled: #{AppSetting.investor_notifications_enabled?}, " \
        "In whitelist: #{in_whitelist?(investor_email)}"
      )
    end
  end
end
