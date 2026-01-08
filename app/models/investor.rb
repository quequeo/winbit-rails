class Investor < ApplicationRecord
  STATUSES = %w[ACTIVE INACTIVE].freeze

  has_one :portfolio, dependent: :destroy
  has_many :portfolio_histories, dependent: :destroy
  has_many :investor_requests, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :generate_code, on: :create

  def status_active?
    status == 'ACTIVE'
  end

  def status_inactive?
    status == 'INACTIVE'
  end

  private

  def generate_code
    return if code.present?

    last_investor = Investor.order(code: :desc).first
    if last_investor&.code&.match?(/\AINV(\d+)\z/)
      last_number = ::Regexp.last_match(1).to_i
      self.code = format('INV%03d', last_number + 1)
    else
      self.code = 'INV001'
    end
  end
end
