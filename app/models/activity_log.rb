class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :target, polymorphic: true

  # Acciones permitidas (para validar y ahorrar espacio)
  ACTIONS = %w[
    approve_request
    reject_request
    update_portfolio
    create_investor
    update_investor
    deactivate_investor
    activate_investor
    delete_investor
    create_admin
    update_admin
    delete_admin
    distribute_profit
    apply_referral_commission
    update_settings
  ].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }

  # Scopes útiles
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :older_than, ->(date) { where('created_at < ?', date) }

  # Método helper para descripción en español
  def action_description
    case action
    when 'approve_request' then 'Solicitud aprobada'
    when 'reject_request' then 'Solicitud rechazada'
    when 'update_portfolio' then 'Portfolio actualizado'
    when 'create_investor' then 'Inversor creado'
    when 'update_investor' then 'Inversor actualizado'
    when 'deactivate_investor' then 'Inversor desactivado'
    when 'activate_investor' then 'Inversor activado'
    when 'delete_investor' then 'Inversor eliminado'
    when 'create_admin' then 'Administrador creado'
    when 'update_admin' then 'Administrador actualizado'
    when 'delete_admin' then 'Administrador eliminado'
    when 'distribute_profit' then 'Ganancias distribuidas'
    when 'apply_referral_commission' then 'Comisión por referido aplicada'
    when 'update_settings' then 'Configuración actualizada'
    else action
    end
  end
end
