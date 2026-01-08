class PortfolioHistory < ApplicationRecord
  STATUSES = %w[PENDING COMPLETED REJECTED].freeze

  belongs_to :investor

  validates :event, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
