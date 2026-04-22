class Investor < ApplicationRecord
  STATUSES = %w[ACTIVE INACTIVE].freeze
  TRADING_FEE_FREQUENCIES = %w[MONTHLY QUARTERLY SEMESTRAL ANNUAL].freeze

  has_secure_password validations: false

  has_one :portfolio, dependent: :destroy
  has_many :portfolio_histories, dependent: :destroy
  has_many :trading_fees, dependent: :destroy
  has_many :investor_requests, dependent: :destroy

  before_destroy :nullify_trading_fee_withdrawal_references

  before_validation :normalize_email

  validates :email,
            presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :trading_fee_frequency, presence: true, inclusion: { in: TRADING_FEE_FREQUENCIES }
  validates :trading_fee_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :password, length: { minimum: 6 }, if: -> { password_digest_changed? || new_record_with_password? }

  def status_active?
    status == 'ACTIVE'
  end

  def status_inactive?
    status == 'INACTIVE'
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def new_record_with_password?
    new_record? && password.present?
  end

  def nullify_trading_fee_withdrawal_references
    # trading_fees.withdrawal_request_id references requests; FK would block investor_requests destroy
    trading_fees.update_all(withdrawal_request_id: nil)
  end
end
