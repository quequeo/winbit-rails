# frozen_string_literal: true

# Revisa cada minuto si hay correos programados que ya deben salir. El estado
# vive en la base, así que un reinicio del dyno no pierde nada: al volver a
# arrancar retoma los pendientes. Se activa con EMAIL_SCHEDULER=1.
Rails.application.config.after_initialize do
  next unless ENV['EMAIL_SCHEDULER'] == '1'

  Thread.new do
    Thread.current.name = 'email-scheduler'
    loop do
      sleep 60
      begin
        ActiveRecord::Base.connection_pool.with_connection { OutgoingEmails::SendDue.call }
      rescue StandardError => e
        Rails.logger.error("[email-scheduler] #{e.class}: #{e.message}")
      end
    end
  end
end
