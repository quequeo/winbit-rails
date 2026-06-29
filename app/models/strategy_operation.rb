class StrategyOperation < ApplicationRecord
  SOURCES = %w[manual import].freeze
  DIRECTIONS = %w[LONG SHORT].freeze
  ASSETS = %w[MNQ MBT MYM MES].freeze
  RESULT_LABELS = %w[POSITIVO NEGATIVO BE+ BE-].freeze
  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :created_by, class_name: 'User'

  validates :operation_date, presence: true
  validates :asset, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :direction, inclusion: { in: DIRECTIONS }, allow_blank: true
  validates :created_by_id, presence: true
  validates :asset, inclusion: { in: ASSETS }, if: :manual_entry?
  validates :result_label, inclusion: { in: RESULT_LABELS }, allow_blank: true, if: :manual_entry?
  validates :opened_at, format: { with: TIME_FORMAT }, allow_blank: true
  validates :closed_at, format: { with: TIME_FORMAT }, allow_blank: true

  def self.valid_time?(value)
    value.to_s.strip.match?(TIME_FORMAT)
  end

  private

  def manual_entry?
    source == 'manual'
  end
end
