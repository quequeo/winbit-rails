class Investor < ApplicationRecord
  STATUSES = %w[ACTIVE INACTIVE].freeze

  has_one :portfolio, dependent: :destroy
  has_many :portfolio_histories, dependent: :destroy
  has_many :investor_requests, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def status_active?
    status == 'ACTIVE'
  end

  def status_inactive?
    status == 'INACTIVE'
  end

  private

  def generate_code
    return if code.present?

    # Extract all numeric codes and find the maximum
    max_number = Investor.pluck(:code)
                         .map { |c| c.match(/\AINV(\d+)\z/)&.captures&.first&.to_i }
                         .compact
                         .max || 0

    self.code = format('INV%03d', max_number + 1)
  end
end
