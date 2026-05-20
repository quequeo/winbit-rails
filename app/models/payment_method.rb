class PaymentMethod < ApplicationRecord
  KINDS = %w[CRYPTO FIAT CASH BANK].freeze
  FLOWS = %w[deposit withdrawal].freeze

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :for_deposit, -> { where(enabled_for_deposit: true) }
  scope :for_withdrawal, -> { where(enabled_for_withdrawal: true) }

  def self.for_flow(flow)
    flow = flow.to_s
    return none unless FLOWS.include?(flow)

    active.ordered.public_send("for_#{flow}")
  end
end
