class TradingFee < ApplicationRecord
  SOURCES = %w[PERIODIC WITHDRAWAL].freeze

  belongs_to :investor
  belongs_to :applied_by, class_name: 'User'
  belongs_to :voided_by, class_name: 'User', optional: true
  belongs_to :withdrawal_request, class_name: 'InvestorRequest', optional: true

  scope :active, -> { where(voided_at: nil) }

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :profit_amount, presence: true, numericality: { greater_than: 0 }
  validates :fee_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :fee_amount, presence: true, numericality: { greater_than: 0 }
  validates :applied_at, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }

  validate :period_end_after_period_start
  validate :no_overlapping_fees_for_same_investor
  validate :withdrawal_fields_when_source_is_withdrawal

  private

  def period_end_after_period_start
    return if period_start.blank? || period_end.blank?

    if period_end <= period_start
      errors.add(:period_end, 'must be after period start')
    end
  end

  def no_overlapping_fees_for_same_investor
    return if investor_id.blank? || period_start.blank? || period_end.blank?
    return if source == 'WITHDRAWAL'

    overlapping = TradingFee.active.where(investor_id: investor_id, source: 'PERIODIC')
                            .where.not(id: id)
                            .where('period_start <= ? AND period_end >= ?', period_end, period_start)

    if overlapping.exists?
      errors.add(:base, 'Trading fee already exists for this period')
    end
  end

  def withdrawal_fields_when_source_is_withdrawal
    return unless source == 'WITHDRAWAL'

    if withdrawal_amount.blank? || withdrawal_amount.to_d <= 0
      errors.add(:withdrawal_amount, 'must be greater than 0 for withdrawal trading fees')
    end
    if voided_at.nil? && withdrawal_request_id.blank?
      errors.add(:withdrawal_request_id, 'is required for withdrawal trading fees')
    end
  end
end
