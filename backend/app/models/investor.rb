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
end
