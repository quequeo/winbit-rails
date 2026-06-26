class StrategyOperation < ApplicationRecord
  SOURCES = %w[manual import].freeze
  DIRECTIONS = %w[LONG SHORT].freeze

  belongs_to :created_by, class_name: 'User'

  validates :operation_date, presence: true
  validates :asset, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :direction, inclusion: { in: DIRECTIONS }, allow_blank: true
  validates :created_by_id, presence: true
end
