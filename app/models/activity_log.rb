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
    when 'approve_request' then 'Aprobó solicitud'
    when 'reject_request' then 'Rechazó solicitud'
    when 'update_portfolio' then 'Actualizó portfolio'
    when 'create_investor' then 'Creó inversor'
    when 'update_investor' then 'Actualizó inversor'
    when 'deactivate_investor' then 'Desactivó inversor'
    when 'activate_investor' then 'Activó inversor'
    when 'delete_investor' then 'Eliminó inversor'
    when 'create_admin' then 'Creó admin'
    when 'update_admin' then 'Actualizó admin'
    when 'delete_admin' then 'Eliminó admin'
    when 'distribute_profit' then 'Distribuyó ganancias'
    when 'update_settings' then 'Actualizó configuración'
    else action
    end
  end
end
