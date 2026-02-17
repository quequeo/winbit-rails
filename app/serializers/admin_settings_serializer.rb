class AdminSettingsSerializer
  def initialize
    @notifications_enabled = AppSetting.investor_notifications_enabled?
    @email_whitelist = AppSetting.investor_email_whitelist
  end

  def as_json(*)
    {
      investor_notifications_enabled: @notifications_enabled,
      investor_email_whitelist: @email_whitelist
    }
  end
end
