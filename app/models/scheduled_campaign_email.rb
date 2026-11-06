# frozen_string_literal: true

# Campaña programada para una fecha y hora. Lo dispara el ticker de correos
# (config/initializers/email_scheduler.rb) vía EmailCampaigns::SendScheduled.
#
# investor_ids en nil significa "todos los inversores activos". Una lista vacía
# no es válida, para que una selección sin nadie nunca termine yendo a todos.
class ScheduledCampaignEmail < ApplicationRecord
  STATUSES = %w[SCHEDULED SENDING SENT CANCELED FAILED].freeze
  MONTH_FORMAT = /\A\d{4}-\d{2}\z/

  belongs_to :scheduled_by, class_name: 'User', optional: true

  validates :month, presence: true, format: { with: MONTH_FORMAT }
  validates :subject, :body, :scheduled_for, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :investor_ids_are_not_empty

  scope :scheduled, -> { where(status: 'SCHEDULED') }
  scope :due, ->(now = Time.current) { scheduled.where(scheduled_for: ..now) }
  scope :recent_first, -> { order(scheduled_for: :desc) }

  private

  def investor_ids_are_not_empty
    errors.add(:investor_ids, 'no puede estar vacío') if investor_ids == []
  end
end
