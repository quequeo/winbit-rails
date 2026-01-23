class DailyOperatingResult < ApplicationRecord
  belongs_to :applied_by, class_name: 'User'

  validates :date, presence: true, uniqueness: true
  validates :percent, presence: true, numericality: { greater_than_or_equal_to: -100, less_than_or_equal_to: 100 }
  validates :applied_by_id, presence: true
  validates :applied_at, presence: true
end
