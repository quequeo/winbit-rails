# frozen_string_literal: true

# Número de operación visible para el inversor (comprobante, mail y app):
# A-2026-0001 para el aporte inicial, I-2026-0001 para los ingresos siguientes
# y R-2026-0001 para los retiros, correlativo por prefijo y año.
module OperationNumber
  ZONE = ActiveSupport::TimeZone['America/Argentina/Buenos_Aires']
  LOCK_KEY = 7_142_026

  module_function

  def assign!(request)
    return request.operation_number if request.operation_number.present?

    prefix = prefix_for(request)
    year = (request.processed_at || Time.current).in_time_zone(ZONE).year

    InvestorRequest.transaction do
      InvestorRequest.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
      last = InvestorRequest.where('operation_number LIKE ?', "#{prefix}-#{year}-%").maximum(:operation_number)
      sequence = last ? last.split('-').last.to_i + 1 : 1
      request.update_columns(operation_number: format('%s-%d-%04d', prefix, year, sequence))
    end
    request.operation_number
  end

  def prefix_for(request)
    return 'R' if request.request_type == 'WITHDRAWAL'

    initial_deposit?(request) ? 'A' : 'I'
  end

  def initial_deposit?(request)
    return false unless request.request_type == 'DEPOSIT'

    !InvestorRequest.where(investor_id: request.investor_id, request_type: 'DEPOSIT', status: %w[APPROVED REVERSED])
                    .where.not(id: request.id)
                    .where('processed_at <= ?', request.processed_at || Time.current)
                    .exists?
  end
end
