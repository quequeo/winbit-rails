class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Keys disponibles
  INVESTOR_NOTIFICATIONS_ENABLED = 'investor_notifications_enabled'
  INVESTOR_EMAIL_WHITELIST = 'investor_email_whitelist'

  # Obtener un setting por key
  def self.get(key)
    setting = find_by(key: key)
    return nil unless setting
    return nil if setting.value.nil?

    # Parse JSON si es un array/hash
    begin
      parsed = JSON.parse(setting.value)
      # Si es un string simple (como "true" o "false"), devolver el string original
      # a menos que sea realmente un array u objeto JSON
      parsed.is_a?(Array) || parsed.is_a?(Hash) ? parsed : setting.value
    rescue JSON::ParserError, TypeError
      setting.value
    end
  end

  # Setear un setting
  def self.set(key, value, description: nil)
    setting = find_or_initialize_by(key: key)
    setting.value = value.is_a?(String) ? value : value.to_json
    setting.description = description if description
    setting.save!
    setting
  end

  # Métodos de conveniencia
  def self.investor_notifications_enabled?
    get(INVESTOR_NOTIFICATIONS_ENABLED) == 'true'
  end

  def self.investor_email_whitelist
    get(INVESTOR_EMAIL_WHITELIST) || []
  end
end
