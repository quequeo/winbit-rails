# frozen_string_literal: true

# Mail al inversor generado por el sistema que espera revisión humana antes
# de salir. Se envía solo cuando un admin lo confirma.
class OutgoingEmail < ApplicationRecord
  KINDS = %w[
    DEPOSIT_APPROVED
    WITHDRAWAL_APPROVED
    DEPOSIT_REJECTED
    WITHDRAWAL_REJECTED
    INVESTOR_WELCOME
    INVESTOR_DEACTIVATED
  ].freeze
  RECEIPT_KINDS = %w[DEPOSIT_APPROVED WITHDRAWAL_APPROVED].freeze
  STATUSES = %w[DRAFT SCHEDULED SENT DISCARDED FAILED].freeze
  PENDING_STATUSES = %w[DRAFT SCHEDULED FAILED].freeze
  UNSCHEDULED_STATUSES = %w[DRAFT FAILED].freeze

  belongs_to :investor
  belongs_to :investor_request, foreign_key: :request_id, optional: true
  belongs_to :sent_by, class_name: 'User', optional: true
  belongs_to :scheduled_by, class_name: 'User', optional: true

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :to_email, :subject, :body_html, presence: true

  scope :pending, -> { where(status: PENDING_STATUSES) }
  scope :recent_first, -> { order(created_at: :desc) }

  def pending?
    PENDING_STATUSES.include?(status)
  end

  def with_receipt?
    RECEIPT_KINDS.include?(kind) && request_id.present?
  end
end
