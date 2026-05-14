# Deshace una aprobación reciente sin dejar eventos de reversión:
# borra las filas de PortfolioHistory (y el TradingFee de retiro si aplica),
# vuelve la solicitud a PENDING y ejecuta PortfolioRecalculator.
#
# Condiciones de seguridad:
# - Solo APPROVED con processed_at.
# - No debe existir OPERATING_RESULT posterior para el inversor (la operativa
#   compone sobre balances ya materializados; corregir el monto sin rehacer
#   la operativa dejaría montos incoherentes).
module Requests
  class ResetApprovedRequestToPending
    TIME_MATCH_SLACK = 3 # seconds — encaje date/processed_at del approve

    def initialize(request_id:)
      @request_id = request_id
    end

    def call
      req = InvestorRequest.includes(:investor).find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo aplica a solicitudes aprobadas' unless req.status == 'APPROVED'
      raise StandardError, 'La solicitud no tiene fecha de procesamiento' if req.processed_at.blank?

      processed_at = req.processed_at

      if operating_result_after?(req.investor_id, processed_at)
        raise StandardError,
              'Hay operativa diaria registrada después de esta aprobación. ' \
              'Revertí o corregí manualmente; esta acción no está disponible.'
      end

      ApplicationRecord.transaction do
        if req.request_type == 'DEPOSIT'
          reset_deposit!(req, processed_at)
        elsif req.request_type == 'WITHDRAWAL'
          reset_withdrawal!(req, processed_at)
        else
          raise StandardError, 'Tipo de solicitud no soportado'
        end

        req.update!(
          status: 'PENDING',
          processed_at: nil
        )
      end

      PortfolioRecalculator.recalculate!(req.investor)
      true
    end

    private

    def operating_result_after?(investor_id, processed_at)
      PortfolioHistory.where(investor_id: investor_id, status: 'COMPLETED', event: 'OPERATING_RESULT')
                      .where('date > ?', processed_at)
                      .exists?
    end

    def time_window(processed_at)
      (processed_at - TIME_MATCH_SLACK.seconds)..(processed_at + TIME_MATCH_SLACK.seconds)
    end

    def reset_deposit!(req, processed_at)
      rows = PortfolioHistory.where(
        investor_id: req.investor_id,
        event: 'DEPOSIT',
        status: 'COMPLETED',
        amount: req.amount
      ).where(date: time_window(processed_at))
        .order(created_at: :desc)

      case rows.size
      when 0
        raise StandardError,
              'No se encontró el movimiento de depósito en el historial (monto/fecha). Revisá datos o usá reversión manual.'
      when 1
        rows.first.destroy!
      else
        raise StandardError,
              'Hay más de un depósito coincidente en el historial; no se puede deshacer de forma automática.'
      end
    end

    def reset_withdrawal!(req, processed_at)
      wd_rows = PortfolioHistory.where(
        investor_id: req.investor_id,
        event: 'WITHDRAWAL',
        status: 'COMPLETED',
        amount: req.amount
      ).where(date: time_window(processed_at))
        .order(created_at: :asc)

      case wd_rows.size
      when 0
        raise StandardError,
              'No se encontró el movimiento de retiro en el historial. Revisá datos o usá reversión manual.'
      when 1
        withdrawal_hist = wd_rows.first
      else
        raise StandardError,
              'Hay más de un retiro coincidente en el historial; no se puede deshacer de forma automática.'
      end

      fee_row = PortfolioHistory.where(
        investor_id: req.investor_id,
        event: 'TRADING_FEE',
        status: 'COMPLETED'
      ).where(date: time_window(processed_at))
        .where('created_at >= ?', withdrawal_hist.created_at)
        .order(created_at: :asc)
        .first

      trading_fee = TradingFee.find_by(withdrawal_request_id: req.id, source: 'WITHDRAWAL')

      if trading_fee.present?
        if fee_row.blank?
          raise StandardError,
                'Existe comisión de trading por retiro pero no el movimiento TRADING_FEE en historial. Revisá datos.'
        end
        fee_row.destroy!
      elsif fee_row.present?
        # Fee en historial sin registro TradingFee (estado inconsistente): igual borramos la fila huérfana.
        fee_row.destroy!
      end

      trading_fee&.destroy!

      withdrawal_hist.destroy!
    end
  end
end
