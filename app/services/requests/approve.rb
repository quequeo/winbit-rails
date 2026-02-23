module Requests
  class Approve
    def initialize(request_id:, processed_at: nil, approved_by: nil)
      @request_id = request_id
      @processed_at_override = processed_at
      @approved_by = approved_by
    end

    def call
      req = InvestorRequest.includes(investor: :portfolio).find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo se pueden aprobar solicitudes pendientes' unless req.status == 'PENDING'

      portfolio = req.investor.portfolio || Portfolio.create!(investor: req.investor)

      processed_at = normalize_processed_at(@processed_at_override) || Time.current

      requested_amount = BigDecimal(req.amount.to_s)

      has_future_history =
        PortfolioHistory.where(investor_id: req.investor_id, status: 'COMPLETED')
                        .where('date > ?', processed_at)
                        .exists?

      withdrawal_fee = nil
      net_withdrawal_amount = requested_amount

      ActiveRecord::Base.transaction do
        req.update!(status: 'APPROVED', processed_at: processed_at)

        if has_future_history
          # Backfilling: compute balance at processed_at and rebuild snapshot from history.
          last = PortfolioHistory.where(investor_id: req.investor_id, status: 'COMPLETED')
                                 .where('date <= ?', processed_at)
                                 .order(date: :desc, created_at: :desc)
                                 .first

          previous_balance = BigDecimal((last ? last.new_balance : portfolio.current_balance).to_s)
          new_balance = if req.request_type == 'DEPOSIT'
            previous_balance + requested_amount
          else
            raise StandardError, 'Balance insuficiente para realizar el retiro' if previous_balance < requested_amount

            withdrawal_fee = build_withdrawal_trading_fee(
              request: req,
              previous_balance: previous_balance,
              requested_amount: requested_amount,
              processed_at: processed_at
            )

            net_withdrawal_amount = withdrawal_fee[:net_withdrawal_amount]
            previous_balance - requested_amount
          end

          if req.request_type == 'DEPOSIT'
            PortfolioHistory.create!(
              investor_id: req.investor_id,
              event: req.request_type,
              amount: requested_amount,
              previous_balance: previous_balance,
              new_balance: new_balance,
              status: 'COMPLETED',
              date: processed_at
            )
          else
            create_withdrawal_histories!(
              request: req,
              previous_balance: previous_balance,
              processed_at: processed_at,
              net_withdrawal_amount: net_withdrawal_amount,
              fee_amount: withdrawal_fee[:fee_amount]
            )
          end

          PortfolioRecalculator.recalculate!(req.investor)
        else
          # Normal case: apply incrementally using current portfolio snapshot.
          previous_balance = BigDecimal(portfolio.current_balance.to_s)
          new_balance = if req.request_type == 'DEPOSIT'
            previous_balance + requested_amount
          else
            raise StandardError, 'Balance insuficiente para realizar el retiro' if previous_balance < requested_amount

            withdrawal_fee = build_withdrawal_trading_fee(
              request: req,
              previous_balance: previous_balance,
              requested_amount: requested_amount,
              processed_at: processed_at
            )

            net_withdrawal_amount = withdrawal_fee[:net_withdrawal_amount]
            previous_balance - requested_amount
          end

          if req.request_type == 'DEPOSIT'
            PortfolioHistory.create!(
              investor_id: req.investor_id,
              event: req.request_type,
              amount: requested_amount,
              previous_balance: previous_balance,
              new_balance: new_balance,
              status: 'COMPLETED',
              date: processed_at
            )
          else
            create_withdrawal_histories!(
              request: req,
              previous_balance: previous_balance,
              processed_at: processed_at,
              net_withdrawal_amount: net_withdrawal_amount,
              fee_amount: withdrawal_fee[:fee_amount]
            )
          end

          # Keep totals consistent without requiring a full history replay.
          new_total_invested =
            if req.request_type == 'DEPOSIT'
              BigDecimal(portfolio.total_invested.to_s) + requested_amount
            else
              BigDecimal(portfolio.total_invested.to_s) - net_withdrawal_amount
            end

          portfolio.update!(
            current_balance: new_balance.to_f,
            total_invested: new_total_invested.to_f,
          )
        end
      end

      # Send approval email notification
      begin
        if req.request_type == 'DEPOSIT'
          InvestorMailer.deposit_approved(req.investor, req).deliver_later
        elsif req.request_type == 'WITHDRAWAL'
          InvestorMailer.withdrawal_approved(req.investor, req, withdrawal_fee).deliver_later
          AdminMailer.withdrawal_approved_notification(req, withdrawal_fee).deliver_later
        end
      rescue => e
        Rails.logger.error("Failed to send approval email: #{e.message}")
        # Continue even if email fails
      end

      true
    end

    private

    # Accepts:
    # - nil
    # - "YYYY-MM-DD" (interpreted as 19:00 local time to preserve ordering after daily operating at 17:00)
    # - ISO datetime string
    # - Time
    def normalize_processed_at(value)
      return value.in_time_zone if value.is_a?(Time)
      return nil if value.blank?

      s = value.to_s.strip
      return nil if s.empty?

      if s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        d = Date.parse(s)
        return Time.zone.local(d.year, d.month, d.day, 19, 0, 0)
      end

      Time.zone.parse(s)
    rescue StandardError
      nil
    end

    def build_withdrawal_trading_fee(request:, previous_balance:, requested_amount:, processed_at:)
      pending_profit = pending_profit_until(investor: request.investor, as_of: processed_at)
      fee_amount = BigDecimal('0')
      realized_profit = BigDecimal('0')
      percentage = BigDecimal(request.investor.trading_fee_percentage.to_s)

      if pending_profit.positive? && previous_balance.positive?
        raise StandardError, 'Usuario aprobador inválido para aplicar trading fee por retiro' if @approved_by.blank?

        realized_profit = (pending_profit * (requested_amount / previous_balance)).round(2, :half_up)
        fee_amount = (realized_profit * (percentage / 100)).round(2, :half_up)
      end

      net_withdrawal_amount = (requested_amount - fee_amount).round(2, :half_up)
      if net_withdrawal_amount <= 0
        raise StandardError, 'El retiro es inválido: el trading fee por retiro no puede dejar neto menor o igual a cero'
      end

      trading_fee = nil
      if fee_amount.positive?
        trading_fee = TradingFee.create!(
          investor: request.investor,
          applied_by: @approved_by,
          period_start: processed_at.to_date,
          period_end: processed_at.to_date + 1.day,
          profit_amount: realized_profit,
          fee_percentage: percentage,
          fee_amount: fee_amount,
          source: 'WITHDRAWAL',
          withdrawal_amount: requested_amount,
          withdrawal_request_id: request.id,
          notes: "Trading Fee por retiro (request ##{request.id})",
          applied_at: processed_at
        )
      end

      {
        fee_amount: fee_amount,
        realized_profit: realized_profit,
        fee_percentage: percentage,
        pending_profit: pending_profit,
        requested_amount: requested_amount,
        net_withdrawal_amount: net_withdrawal_amount,
        trading_fee_id: trading_fee&.id
      }
    end

    def pending_profit_until(investor:, as_of:)
      operating_profit = PortfolioHistory.where(investor_id: investor.id, event: 'OPERATING_RESULT', status: 'COMPLETED')
                                         .where('date <= ?', as_of)
                                         .sum(:amount)
      feeed_profit = TradingFee.active.where(investor_id: investor.id)
                                      .where('applied_at <= ?', as_of)
                                      .sum(:profit_amount)

      pending = BigDecimal(operating_profit.to_s) - BigDecimal(feeed_profit.to_s)
      pending.positive? ? pending : BigDecimal('0')
    end

    def create_withdrawal_histories!(request:, previous_balance:, processed_at:, net_withdrawal_amount:, fee_amount:)
      withdrawal_new_balance = previous_balance - net_withdrawal_amount
      PortfolioHistory.create!(
        investor_id: request.investor_id,
        event: 'WITHDRAWAL',
        amount: net_withdrawal_amount,
        previous_balance: previous_balance,
        new_balance: withdrawal_new_balance,
        status: 'COMPLETED',
        date: processed_at
      )

      return if fee_amount <= 0

      PortfolioHistory.create!(
        investor_id: request.investor_id,
        event: 'TRADING_FEE',
        amount: -fee_amount,
        previous_balance: withdrawal_new_balance,
        new_balance: withdrawal_new_balance - fee_amount,
        status: 'COMPLETED',
        date: processed_at
      )
    end
  end
end
