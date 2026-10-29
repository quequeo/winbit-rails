# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Runs InvestorMonthlyReportPdfs::Generate for every active investor
  # missing a report, off the request thread. "Generar todos" was timing
  # out (Heroku's router kills any request over 30s) and taking the dyno's
  # memory with it once there were enough investors for the per-PDF Chrome
  # renders to add up - this moves that work onto ActiveJob's :async adapter
  # (already what InvestorMailer's deliver_later calls use in this app, no
  # new infrastructure needed) so the controller can respond immediately.
  #
  # El avance queda guardado en GenerationRun: si el dyno se reinicia a mitad
  # de camino, GenerationWatchdog vuelve a encolar este job y sigue con los
  # que faltan.
  class GenerateAllJob < ApplicationJob
    queue_as :default

    MUTEX = Mutex.new
    @running = false

    # Guards against a double-click (or anyone re-clicking "Generar todos"
    # because the first click didn't look like it did anything) running a
    # second job in this same process while the first is still working -
    # that's exactly what took the dyno down (two runs, each launching its
    # own Chrome processes, same time). GenerationRun covers the "is there a
    # run going" check across restarts; this covers the race between two
    # requests that both read "not running" before either job started.
    def self.running_here?
      MUTEX.synchronize { @running }
    end

    def self.claim
      MUTEX.synchronize do
        next false if @running

        @running = true
      end
    end

    def self.release
      MUTEX.synchronize { @running = false }
    end

    def perform(month:, generated_by_id:)
      return unless self.class.claim

      begin
        run = GenerationRun.start!(month: month, generated_by_id: generated_by_id)
        if run['attempts'] > GenerationRun::MAX_ATTEMPTS
          Rails.logger.error("[InvestorMonthlyReportPdfs::GenerateAllJob] month=#{month} aborted after #{GenerationRun::MAX_ATTEMPTS} attempts")
          GenerationRun.finish!(aborted: true)
          return
        end

        generated_by = User.find_by(id: generated_by_id)
        result = InvestorMonthlyReportPdfs::Generate.call(
          month: month,
          generated_by: generated_by,
          on_progress: ->(**progress) { GenerationRun.progress!(**progress) }
        )
        GenerationRun.finish!

        Rails.logger.info(
          "[InvestorMonthlyReportPdfs::GenerateAllJob] month=#{month} " \
          "generated=#{result.generated.size} skipped=#{result.skipped.size} failed=#{result.failed.size}"
        )
        result.failed.each do |f|
          Rails.logger.error("[InvestorMonthlyReportPdfs::GenerateAllJob] investor=#{f[:investor].id} error=#{f[:error]}")
        end
      ensure
        self.class.release
      end
    end
  end
end
