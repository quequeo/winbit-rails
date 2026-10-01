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

    MUTEX = Mutex.new
    RUNNING_MONTHS = {}

    # Guards against a double-click (or anyone re-clicking "Generar todos"
    # because the first click didn't look like it did anything) enqueueing
    # a second run for the same month while the first is still working -
    # that's exactly what took the dyno down (two runs, each launching its
    # own Chrome processes, same time). Per-process only (this app runs a
    # single web dyno), which is what matters here.
    def self.running?(month)
      MUTEX.synchronize { RUNNING_MONTHS[month].present? }
    end

    def perform(month:, generated_by_id:)
      return if self.class.running?(month)

      MUTEX.synchronize { RUNNING_MONTHS[month] = true }
      begin
        generated_by = User.find_by(id: generated_by_id)
        result = InvestorMonthlyReportPdfs::Generate.call(month: month, generated_by: generated_by)

        Rails.logger.info(
          "[InvestorMonthlyReportPdfs::GenerateAllJob] month=#{month} " \
          "generated=#{result.generated.size} skipped=#{result.skipped.size} failed=#{result.failed.size}"
        )
        result.failed.each do |f|
          Rails.logger.error("[InvestorMonthlyReportPdfs::GenerateAllJob] investor=#{f[:investor].id} error=#{f[:error]}")
        end
      ensure
        MUTEX.synchronize { RUNNING_MONTHS.delete(month) }
      end
    end
  end
end
