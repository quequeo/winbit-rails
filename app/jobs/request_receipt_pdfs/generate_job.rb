# frozen_string_literal: true

module RequestReceiptPdfs
  class GenerateJob < ApplicationJob
    queue_as :default

    def perform(request_id:, balance_after: nil)
      request = InvestorRequest.includes(:investor).find_by(id: request_id)
      return unless request&.status == 'APPROVED'

      RequestReceiptPdfs::Generate.call(request: request, balance_after: balance_after.presence)
    rescue StandardError => e
      Rails.logger.error("[RequestReceiptPdfs::GenerateJob] request=#{request_id}: #{e.class}: #{e.message}")
    end
  end
end
