# frozen_string_literal: true

class InvestorMonthlyReportPdf < ApplicationRecord
  MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/
  MAX_BYTES = 15.megabytes
  PDF_MAGIC = '%PDF'

  belongs_to :investor
  belongs_to :uploaded_by, class_name: 'User', optional: true

  validates :month, presence: true, format: { with: MONTH_FORMAT }
  validates :original_filename, presence: true
  validates :content_type, presence: true
  validates :byte_size, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: MAX_BYTES }
  validates :pdf_data, presence: true
  validates :month, uniqueness: { scope: :investor_id }
  validate :pdf_data_looks_like_pdf

  scope :for_month, ->(month) { where(month: month) }
  scope :ordered, -> { order(:month, :original_filename) }
  scope :without_pdf_data, -> { select(column_names - [ 'pdf_data' ]) }

  def self.last_closed_month(today = Date.current)
    today.prev_month.strftime('%Y-%m')
  end

  def download_filename
    name = File.basename(original_filename.to_s)
    return name if name.downcase.end_with?('.pdf')

    "Reporte #{month}.pdf"
  end

  def email_attachment_filename
    month_name = InvestorMonthlyReportPdfs::Month.spanish_name(month) || month
    year = InvestorMonthlyReportPdfs::Month.year(month)
    label = investor.name.to_s.upcase.gsub(/[\\\/]/, ' ').squish
    "Reporte #{month_name} #{year} - #{label}.pdf"
  end

  private

  def pdf_data_looks_like_pdf
    return if pdf_data.blank?
    return if pdf_data.byteslice(0, 4).to_s.start_with?(PDF_MAGIC)

    errors.add(:pdf_data, 'no es un PDF válido')
  end
end
