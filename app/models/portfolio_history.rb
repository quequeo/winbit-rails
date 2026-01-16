class PortfolioHistory < ApplicationRecord
  EVENTS = %w[DEPOSIT WITHDRAWAL PROFIT TRADING_FEE REFERRAL_COMMISSION].freeze
  STATUSES = %w[PENDING COMPLETED REJECTED].freeze

  belongs_to :investor

  validates :event, presence: true, inclusion: { in: EVENTS }
  validates :status, presence: true, inclusion: { in: STATUSES }
end
