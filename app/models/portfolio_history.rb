class PortfolioHistory < ApplicationRecord
  EVENTS = %w[DEPOSIT WITHDRAWAL DEPOSIT_REVERSAL OPERATING_RESULT TRADING_FEE TRADING_FEE_ADJUSTMENT REFERRAL_COMMISSION].freeze
  STATUSES = %w[PENDING COMPLETED REJECTED].freeze

  belongs_to :investor

  validates :event, presence: true, inclusion: { in: EVENTS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount, :previous_balance, :new_balance, presence: true, numericality: true

  validate :amount_sign_for_event
  validate :completed_balance_consistency

  private

  def amount_sign_for_event
    return if amount.blank? || event.blank?

    errors.add(:amount, 'must be greater than 0 for WITHDRAWAL') if event == 'WITHDRAWAL' && amount.to_d <= 0
    errors.add(:amount, 'must be greater than 0 for DEPOSIT_REVERSAL') if event == 'DEPOSIT_REVERSAL' && amount.to_d <= 0
    errors.add(:amount, 'must be lower than 0 for TRADING_FEE') if event == 'TRADING_FEE' && amount.to_d >= 0
  end

  def completed_balance_consistency
    return unless status == 'COMPLETED'
    return if amount.blank? || previous_balance.blank? || new_balance.blank?
    return if amount.to_d.zero?

    expected =
      if %w[WITHDRAWAL DEPOSIT_REVERSAL].include?(event)
        previous_balance.to_d - amount.to_d
      else
        previous_balance.to_d + amount.to_d
      end

    return if (new_balance.to_d - expected).abs <= BigDecimal('0.01')

    errors.add(:new_balance, 'must be consistent with previous_balance and amount')
  end
end
