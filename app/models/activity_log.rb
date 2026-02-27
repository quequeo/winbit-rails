class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :target, polymorphic: true

  # Acciones permitidas (para validar y ahorrar espacio)
  ACTIONS = %w[
    approve_request
    reject_request
    reverse_withdrawal
    reverse_deposit
    create_request
    update_request
    delete_request
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
    apply_trading_fee
    update_trading_fee
    void_trading_fee
    create_deposit_option
    update_deposit_option
    delete_deposit_option
    toggle_deposit_option
    update_settings
  ].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :older_than, ->(date) { where('created_at < ?', date) }

  def action_description
    I18N_ACTIONS[action] || action
  end

  I18N_ACTIONS = {
    'approve_request' => 'Solicitud aprobada',
    'reject_request' => 'Solicitud rechazada',
    'reverse_withdrawal' => 'Retiro revertido',
    'reverse_deposit' => 'Depósito revertido',
    'create_request' => 'Solicitud creada',
    'update_request' => 'Solicitud actualizada',
    'delete_request' => 'Solicitud eliminada',
    'update_portfolio' => 'Portfolio actualizado',
    'create_investor' => 'Inversor creado',
    'update_investor' => 'Inversor actualizado',
    'deactivate_investor' => 'Inversor desactivado',
    'activate_investor' => 'Inversor activado',
    'delete_investor' => 'Inversor eliminado',
    'create_admin' => 'Administrador creado',
    'update_admin' => 'Administrador actualizado',
    'delete_admin' => 'Administrador eliminado',
    'distribute_profit' => 'Ganancias distribuidas',
    'apply_referral_commission' => 'Comisión por referido aplicada',
    'apply_trading_fee' => 'Trading fee aplicado',
    'update_trading_fee' => 'Trading fee actualizado',
    'void_trading_fee' => 'Trading fee anulado',
    'create_deposit_option' => 'Opción de depósito creada',
    'update_deposit_option' => 'Opción de depósito actualizada',
    'delete_deposit_option' => 'Opción de depósito eliminada',
    'toggle_deposit_option' => 'Opción de depósito activada/desactivada',
    'update_settings' => 'Configuración actualizada',
  }.freeze
end
