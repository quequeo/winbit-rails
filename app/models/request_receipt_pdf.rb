# frozen_string_literal: true

class RequestReceiptPdf < ApplicationRecord
  PDF_MAGIC = '%PDF'

  belongs_to :investor_request, foreign_key: :request_id, inverse_of: :receipt_pdf

  validates :original_filename, presence: true
  validates :content_type, presence: true
  validates :byte_size, presence: true, numericality: { greater_than: 0 }
  validates :pdf_data, presence: true
  validates :request_id, uniqueness: true
  validate :pdf_data_looks_like_pdf

  scope :without_pdf_data, -> { select(column_names - [ 'pdf_data' ]) }

  private

  def pdf_data_looks_like_pdf
    return if pdf_data.blank?
    return if pdf_data.byteslice(0, 4).to_s.start_with?(PDF_MAGIC)

    errors.add(:pdf_data, 'no es un PDF válido')
  end
end
