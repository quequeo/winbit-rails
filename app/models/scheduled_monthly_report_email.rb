# frozen_string_literal: true

# Envío masivo del reporte mensual programado para una fecha y hora. Lo
# dispara el ticker de correos del proceso web (config/initializers/
# email_scheduler.rb) vía InvestorMonthlyReportEmails::SendScheduled.
#
# Destinatarios y PDFs se toman al momento de enviar, no al programar: si se
# regenera un PDF entre medio, sale el último.
class ScheduledMonthlyReportEmail < ApplicationRecord
  STATUSES = %w[SCHEDULED SENDING SENT CANCELED FAILED].freeze

  belongs_to :scheduled_by, class_name: 'User', optional: true

  validates :month, presence: true, format: { with: InvestorMonthlyReportPdf::MONTH_FORMAT }
  validates :subject, :body, :scheduled_for, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :scheduled, -> { where(status: 'SCHEDULED') }
  scope :due, ->(now = Time.current) { scheduled.where(scheduled_for: ..now) }
end
