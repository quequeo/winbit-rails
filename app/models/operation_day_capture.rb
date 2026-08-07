class OperationDayCapture < ApplicationRecord
  belongs_to :created_by, class_name: 'User', optional: true

  validates :capture_date, presence: true
  validates :original_filename, presence: true, uniqueness: true
  validates :content_type, presence: true
  validates :byte_size, presence: true, numericality: { greater_than: 0 }
  validates :image_data, presence: true
  validates :asset, inclusion: { in: StrategyOperation::ASSETS }, allow_blank: true
  validates :result_label, inclusion: { in: StrategyOperation::RESULT_LABELS }, allow_blank: true

  scope :for_date, ->(date) { where(capture_date: date) }
  scope :between, ->(from_date, to_date) { where(capture_date: from_date..to_date) }
  scope :ordered, -> { order(:capture_date, :original_filename) }
end
