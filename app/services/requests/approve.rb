module Requests
  class Approve
    def initialize(request_id:)
      @request_id = request_id
    end

    def call
      req = InvestorRequest.includes(investor: :portfolio).find_by(id: @request_id)
      raise StandardError, 'Solicitud no encontrada' unless req
      raise StandardError, 'Solo se pueden aprobar solicitudes pendientes' unless req.status == 'PENDING'

      portfolio = req.investor.portfolio
      raise StandardError, 'El inversor no tiene un portfolio' unless portfolio

      previous_balance = BigDecimal(portfolio.current_balance.to_s)
      amount = BigDecimal(req.amount.to_s)

      new_balance = if req.request_type == 'DEPOSIT'
        previous_balance + amount
      else
        raise StandardError, 'Balance insuficiente para realizar el retiro' if previous_balance < amount
        previous_balance - amount
      end

      ActiveRecord::Base.transaction do
        # Update total_invested: add deposits, subtract withdrawals
        new_total_invested = if req.request_type == 'DEPOSIT'
          BigDecimal(portfolio.total_invested.to_s) + amount
        else
          BigDecimal(portfolio.total_invested.to_s) - amount
        end

        portfolio.update!(
          current_balance: new_balance,
          total_invested: new_total_invested,
        )

        req.update!(status: 'APPROVED', processed_at: Time.current)

        PortfolioHistory.create!(
          investor_id: req.investor_id,
          event: req.request_type, # Use request_type directly (DEPOSIT or WITHDRAWAL)
          amount: amount,
          previous_balance: previous_balance,
          new_balance: new_balance,
          status: 'COMPLETED',
          date: Time.current,
        )
      end

      true
    end
  end
end
