class PortfolioHistory < ApplicationRecord
  EVENTS = %w[DEPOSIT WITHDRAWAL PROFIT].freeze
  STATUSES = %w[PENDING COMPLETED REJECTED].freeze

  belongs_to :investor

  validates :event, presence: true, inclusion: { in: EVENTS }
  validates :status, presence: true, inclusion: { in: STATUSES }
end
