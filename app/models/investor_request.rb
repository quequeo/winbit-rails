class InvestorRequest < ApplicationRecord
  self.table_name = 'requests'

  TYPES = %w[DEPOSIT WITHDRAWAL].freeze
  # Keep legacy methods for existing data/tests, but also allow new simplified
  # methods used by winbit-app.
  METHODS = %w[
    USDT
    USDC
    LEMON_CASH
    CASH
    SWIFT
    CASH_ARS
    CASH_USD
    TRANSFER_ARS
    CRYPTO
  ].freeze
  STATUSES = %w[PENDING APPROVED REJECTED REVERSED].freeze
  NETWORKS = %w[TRC20 BEP20 ERC20 POLYGON].freeze
  CRYPTO_WITHDRAWAL_METHODS = %w[CRYPTO].freeze

  belongs_to :investor
  belongs_to :reversed_by, class_name: 'User', optional: true

  validates :request_type, presence: true, inclusion: { in: TYPES }
  validates :method, presence: true, inclusion: { in: METHODS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount, numericality: { greater_than: 0 }

  validate :network_allowed
  validate :crypto_withdrawal_destination_required

  private

  def network_allowed
    return if network.blank?
    errors.add(:network, 'is invalid') unless NETWORKS.include?(network)
  end

  def crypto_withdrawal_destination_required
    return unless request_type == 'WITHDRAWAL'
    return unless CRYPTO_WITHDRAWAL_METHODS.include?(method)

    errors.add(:network, 'is required for crypto withdrawals') if network.blank?
    errors.add(:wallet_address, 'is required for crypto withdrawals') if wallet_address.blank?
  end
end
