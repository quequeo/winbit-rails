# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Runs InvestorMonthlyReportPdfs::Generate for every active investor
  # missing a report, off the request thread. "Generar todos" was timing
  # out (Heroku's router kills any request over 30s) and taking the dyno's
  # memory with it once there were enough investors for the per-PDF Chrome
  # renders to add up - this moves that work onto ActiveJob's :async adapter
  # (already what InvestorMailer's deliver_later calls use in this app, no
  # new infrastructure needed) so the controller can respond immediately.
  class GenerateAllJob < ApplicationJob
    queue_as :default

    def perform(month:, generated_by_id:)
      generated_by = User.find_by(id: generated_by_id)
      result = InvestorMonthlyReportPdfs::Generate.call(month: month, generated_by: generated_by)

      Rails.logger.info(
        "[InvestorMonthlyReportPdfs::GenerateAllJob] month=#{month} " \
        "generated=#{result.generated.size} skipped=#{result.skipped.size} failed=#{result.failed.size}"
      )
      return if result.failed.empty?

      result.failed.each do |f|
        Rails.logger.error("[InvestorMonthlyReportPdfs::GenerateAllJob] investor=#{f[:investor].id} error=#{f[:error]}")
      end
    end
  end
end
