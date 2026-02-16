class Investor < ApplicationRecord
  STATUSES = %w[ACTIVE INACTIVE].freeze
  TRADING_FEE_FREQUENCIES = %w[QUARTERLY SEMESTRAL ANNUAL].freeze

  has_one :portfolio, dependent: :destroy
  has_many :portfolio_histories, dependent: :destroy
  has_many :investor_requests, dependent: :destroy
  has_many :trading_fees, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :trading_fee_frequency, presence: true, inclusion: { in: TRADING_FEE_FREQUENCIES }

  def status_active?
    status == 'ACTIVE'
  end

  def status_inactive?
    status == 'INACTIVE'
  end
end
