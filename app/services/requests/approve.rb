module Requests
  class Approve
    def initialize(request_id:, processed_at: nil)
      @request_id = request_id
      @processed_at_override = processed_at
    end

    def call
      req = InvestorRequest.includes(investor: :portfolio).find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo se pueden aprobar solicitudes pendientes' unless req.status == 'PENDING'

      portfolio = req.investor.portfolio || Portfolio.create!(investor: req.investor)

      processed_at = normalize_processed_at(@processed_at_override) || Time.current

      amount = BigDecimal(req.amount.to_s)

      has_future_history =
        PortfolioHistory.where(investor_id: req.investor_id, status: 'COMPLETED')
                        .where('date > ?', processed_at)
                        .exists?

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
            previous_balance + amount
          else
            raise StandardError, 'Balance insuficiente para realizar el retiro' if previous_balance < amount
            previous_balance - amount
          end

          PortfolioHistory.create!(
            investor_id: req.investor_id,
            event: req.request_type, # DEPOSIT or WITHDRAWAL
            amount: amount,
            previous_balance: previous_balance,
            new_balance: new_balance,
            status: 'COMPLETED',
            date: processed_at,
          )

          PortfolioRecalculator.recalculate!(req.investor)
        else
          # Normal case: apply incrementally using current portfolio snapshot.
          previous_balance = BigDecimal(portfolio.current_balance.to_s)
          new_balance = if req.request_type == 'DEPOSIT'
            previous_balance + amount
          else
            raise StandardError, 'Balance insuficiente para realizar el retiro' if previous_balance < amount
            previous_balance - amount
          end

          PortfolioHistory.create!(
            investor_id: req.investor_id,
            event: req.request_type, # DEPOSIT or WITHDRAWAL
            amount: amount,
            previous_balance: previous_balance,
            new_balance: new_balance,
            status: 'COMPLETED',
            date: processed_at,
          )

          # Keep totals consistent without requiring a full history replay.
          new_total_invested =
            if req.request_type == 'DEPOSIT'
              BigDecimal(portfolio.total_invested.to_s) + amount
            else
              BigDecimal(portfolio.total_invested.to_s) - amount
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
          InvestorMailer.withdrawal_approved(req.investor, req).deliver_later
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
  end
end
