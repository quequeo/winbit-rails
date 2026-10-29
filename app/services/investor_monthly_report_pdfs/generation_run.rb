# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Estado de "Generar todos" guardado en la base (AppSetting), no en memoria.
  #
  # El job corre dentro del proceso web (ActiveJob :async): si Heroku reinicia
  # el dyno a mitad de camino (reinicio diario, deploy), el job se corta sin
  # avisar. Así quedaron 11 PDFs de septiembre sin generar. Con el estado en
  # la base, GenerationWatchdog detecta la corrida cortada y la retoma (los
  # PDFs ya generados se saltean), y la pantalla puede mostrar el avance
  # aunque se recargue.
  #
  # Hay una sola corrida a la vez: los renders de Chrome igual se hacen de a
  # uno (Generate::RENDER_MUTEX).
  class GenerationRun
    KEY = 'monthly_report_generation_run'
    # Cada PDF tarda ~15s; el primero después de un reinicio además descarga
    # Chrome. Sin señales de vida por más que esto, la corrida está cortada.
    STALE_AFTER = 5.minutes
    MAX_ATTEMPTS = 3

    class << self
      def current
        value = AppSetting.get(KEY)
        value.is_a?(Hash) ? value : nil
      end

      def active?(run = current)
        run.present? && run['finished_at'].blank?
      end

      # Corrida sin terminar cuyo proceso ya no da señales: o se reinició el
      # dyno (último latido anterior al arranque de este proceso) o hace rato
      # que no avanza.
      def stalled?(run = current, booted_at: nil, now: Time.current)
        return false unless active?(run)

        heartbeat = Time.zone.parse(run['heartbeat_at'].to_s)
        return true if heartbeat.nil?

        heartbeat < now - STALE_AFTER || (booted_at.present? && heartbeat < booted_at)
      end

      def running?(run = current)
        active?(run) && !stalled?(run)
      end

      def start!(month:, generated_by_id:)
        previous = current
        resuming = active?(previous) && previous['month'] == month
        now = Time.current.iso8601
        generated_before = resuming ? previous['generated'].to_i : 0

        write(
          'month' => month,
          'generated_by_id' => generated_by_id,
          'started_at' => resuming ? previous['started_at'] : now,
          'heartbeat_at' => now,
          'attempts' => resuming ? previous['attempts'].to_i + 1 : 1,
          'processed' => 0,
          'total' => nil,
          # En un reintento los PDFs ya generados existen y Generate los
          # saltea: se guardan aparte para no perderlos del conteo final.
          'generated_before' => generated_before,
          'generated' => generated_before,
          'failed' => [],
          'finished_at' => nil,
        )
      end

      def progress!(processed:, total:, generated:, failed:)
        run = current || {}
        write(
          run.merge(
            'heartbeat_at' => Time.current.iso8601,
            'processed' => processed,
            'total' => total,
            'generated' => run['generated_before'].to_i + generated,
            'failed' => failed,
          )
        )
      end

      def finish!(aborted: false)
        run = current
        return unless run

        write(run.merge('finished_at' => Time.current.iso8601, 'aborted' => aborted))
      end

      def as_json_for_admin
        run = current
        return nil unless run

        {
          month: run['month'],
          running: running?(run),
          stalled: stalled?(run),
          processed: run['processed'].to_i,
          total: run['total'],
          generated: run['generated'].to_i,
          failed: Array(run['failed']),
          aborted: run['aborted'] == true,
          startedAt: run['started_at'],
          finishedAt: run['finished_at'],
        }
      end

      private

      def write(run)
        AppSetting.set(KEY, run, description: 'Estado de la generación automática de reportes mensuales')
        run
      end
    end
  end
end
