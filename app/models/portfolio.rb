class Portfolio < ApplicationRecord
  belongs_to :investor

  validates :investor_id, presence: true, uniqueness: true

  validates :current_balance, numericality: { greater_than_or_equal_to: 0 }
  validates :total_invested, numericality: { greater_than_or_equal_to: 0 }
end
