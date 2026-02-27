module Requests
  class ReverseApprovedDeposit
    def initialize(request_id:, reversed_by:)
      @request_id = request_id
      @reversed_by = reversed_by
    end

    def call
      req = InvestorRequest.includes(investor: :portfolio).find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo se puede revertir una solicitud de depósito aprobada' unless req.status == 'APPROVED' && req.request_type == 'DEPOSIT'

      portfolio = req.investor.portfolio || Portfolio.create!(investor: req.investor)
      requested_amount = BigDecimal(req.amount.to_s)

      ApplicationRecord.transaction do
        previous_balance = BigDecimal(portfolio.current_balance.to_s)
        new_balance = (previous_balance - requested_amount).round(2, :half_up)

        PortfolioHistory.create!(
          investor: req.investor,
          event: 'DEPOSIT_REVERSAL',
          amount: requested_amount,
          previous_balance: previous_balance.to_f,
          new_balance: new_balance.to_f,
          status: 'COMPLETED',
          date: Time.current
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
