# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Hilo de fondo del proceso web (se arranca desde config/puma.rb, así no
  # corre en consolas, `rails runner` ni en la fase release).
  #
  # - Descarga Chrome apenas arranca el dyno, para que el primer PDF después
  #   de un reinicio no tenga que esperar la descarga (un "Generar"
  #   individual podía pasarse de los 30s de Heroku).
  # - Cada minuto revisa si quedó una corrida de "Generar todos" cortada
  #   (GenerationRun) y, si la hay, la vuelve a encolar.
  class GenerationWatchdog
    FIRST_CHECK_AFTER = 30.seconds
    CHECK_EVERY = 1.minute

    def self.start(warm_chrome: Rails.env.production?)
      booted_at = Time.current

      Thread.new do
        Thread.current.name = 'report-generation-watchdog'
        warm_up_chrome if warm_chrome
        sleep FIRST_CHECK_AFTER
        loop do
          check(booted_at: booted_at)
          sleep CHECK_EVERY
        end
      end
    end

    def self.check(booted_at:)
      ActiveRecord::Base.connection_pool.with_connection do
        run = GenerationRun.current
        next unless GenerationRun.stalled?(run, booted_at: booted_at)
        next if GenerateAllJob.running_here?

        Rails.logger.info("[report-generation-watchdog] retomando la generación de #{run['month']}")
        GenerateAllJob.perform_later(month: run['month'], generated_by_id: run['generated_by_id'])
      end
    rescue StandardError => e
      Rails.logger.error("[report-generation-watchdog] #{e.class}: #{e.message}")
    end

    def self.warm_up_chrome
      EnsureChromeInstalled.call
    rescue StandardError => e
      Rails.logger.error("[report-generation-watchdog] no se pudo instalar Chrome: #{e.class}: #{e.message}")
    end
  end
end
