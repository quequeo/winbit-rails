class Investor < ApplicationRecord
  STATUSES = %w[ACTIVE INACTIVE].freeze
  TRADING_FEE_FREQUENCIES = %w[MONTHLY QUARTERLY SEMESTRAL ANNUAL].freeze

  has_secure_password validations: false

  has_one :portfolio, dependent: :destroy
  has_many :portfolio_histories, dependent: :destroy
  has_many :investor_requests, dependent: :destroy
  has_many :trading_fees, dependent: :destroy

  before_validation :normalize_email

  validates :email,
            presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :trading_fee_frequency, presence: true, inclusion: { in: TRADING_FEE_FREQUENCIES }
  validates :trading_fee_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
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
end
