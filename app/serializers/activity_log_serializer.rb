class ActivityLogSerializer
  def initialize(log)
    @log = log
  end

  def as_json(*)
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
        display: target_display
      },
      metadata: log.metadata,
      created_at: log.created_at
    }
  end

  private

  attr_reader :log

  def target_display
    case log.target_type
    when 'Investor'
      log.target&.name || "Inversor ##{log.target_id}"
    when 'Portfolio'
      investor = log.target&.investor
      investor ? "Portfolio de #{investor.name}" : "Portfolio ##{log.target_id}"
    when 'InvestorRequest'
      req = log.target
      req ? "#{req.request_type} - $#{req.amount}" : "Solicitud ##{log.target_id}"
    when 'TradingFee'
      fee = log.target
      if fee
        investor_name = fee.investor&.name || "Inversor ##{fee.investor_id}"
        "#{investor_name} — $#{fee.fee_amount}"
      else
        "Trading fee ##{log.target_id}"
      end
    when 'DepositOption'
      option = log.target
      option ? "#{option.category}: #{option.label}" : "Opción de depósito ##{log.target_id}"
    when 'User'
      log.target&.name || "Admin ##{log.target_id}"
    when 'AppSetting'
      app_setting_display
    else
      "#{log.target_type} ##{log.target_id}"
    end
  end

  def app_setting_display
    setting = log.target
    return "Configuración ##{log.target_id}" unless setting

    case setting.key
    when 'investor_notifications_enabled'
      'Notificaciones a Inversores (Habilitado/Deshabilitado)'
    when 'investor_email_whitelist'
      'Lista Blanca de Emails de Inversores'
    else
      setting.description || setting.key
    end
  end
end
