module Requests
  class ReverseApprovedWithdrawal
    def initialize(request_id:, reversed_by:)
      @request_id = request_id
      @reversed_by = reversed_by
    end

    def call
      req = InvestorRequest.includes(investor: :portfolio).find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo se puede revertir una solicitud de retiro aprobada' unless req.status == 'APPROVED' && req.request_type == 'WITHDRAWAL'

      portfolio = req.investor.portfolio || Portfolio.create!(investor: req.investor)
      requested_amount = BigDecimal(req.amount.to_s)
      fee = TradingFee.active.find_by(withdrawal_request_id: req.id, source: 'WITHDRAWAL')
      fee_amount = BigDecimal((fee&.fee_amount || 0).to_s)

      ApplicationRecord.transaction do
        running_balance = BigDecimal(portfolio.current_balance.to_s)

        if fee_amount.positive? && fee
          fee_refund_new_balance = running_balance + fee_amount
          PortfolioHistory.create!(
            investor: req.investor,
            event: 'TRADING_FEE_ADJUSTMENT',
            amount: fee_amount,
            previous_balance: running_balance,
            new_balance: fee_refund_new_balance,
            status: 'COMPLETED',
            date: Time.current
          )
          fee.update!(voided_at: Time.current, voided_by: @reversed_by, withdrawal_request_id: nil)
          running_balance = fee_refund_new_balance
        end

        deposit_new_balance = running_balance + requested_amount
        PortfolioHistory.create!(
          investor: req.investor,
          event: 'DEPOSIT',
          amount: requested_amount,
          previous_balance: running_balance,
          new_balance: deposit_new_balance,
          status: 'COMPLETED',
          date: Time.current
        )

        portfolio.update!(
          current_balance: (BigDecimal(portfolio.current_balance.to_s) + requested_amount + fee_amount).to_f,
          total_invested: (BigDecimal(portfolio.total_invested.to_s) + requested_amount).to_f
        )

        req.update!(
          status: 'REVERSED',
          reversed_at: Time.current,
          reversed_by_id: @reversed_by.id
        )
      end

      PortfolioRecalculator.recalculate!(req.investor)
      true
    end
  end
end
