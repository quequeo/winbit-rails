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
  STATUSES = %w[PENDING APPROVED REJECTED].freeze
  NETWORKS = %w[TRC20 BEP20 ERC20 POLYGON].freeze

  belongs_to :investor

  validates :request_type, presence: true, inclusion: { in: TYPES }
  validates :method, presence: true, inclusion: { in: METHODS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount, numericality: { greater_than: 0 }

  validate :network_allowed

  private

  def network_allowed
    return if network.blank?
    errors.add(:network, 'is invalid') unless NETWORKS.include?(network)
  end
end
