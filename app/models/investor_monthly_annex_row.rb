# frozen_string_literal: true

class InvestorMonthlyAnnexRow < ApplicationRecord
  SOURCES = %w[spreadsheet platform].freeze

  belongs_to :investor

  validates :month, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :month, uniqueness: { scope: :investor_id }
  validates :deposits, :withdrawals, :service_cost, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:month, :entry_row) }
  scope :spreadsheet, -> { where(source: 'spreadsheet') }

  def self.spreadsheet_cutoff_month
    Date.new(2026, 4, 1)
  end
end
