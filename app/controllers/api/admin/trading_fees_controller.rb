module Api
  module Admin
    class TradingFeesController < BaseController
      before_action :set_investor, only: [:calculate, :create]
      before_action :set_trading_fee, only: [:update, :destroy]

      # GET /api/admin/trading_fees
      # Lista todas las comisiones aplicadas con filtros opcionales
      def index
        fees = TradingFee.includes(:investor, :applied_by)
                         .order(applied_at: :desc)

        fees = fees.where(investor_id: params[:investor_id]) if params[:investor_id].present?

        if params[:period_start].present? && params[:period_end].present?
          fees = fees.where('period_start >= ? AND period_end <= ?', params[:period_start], params[:period_end])
        end

        render json: fees.map { |fee| serialize_trading_fee(fee) }
      end

      # GET /api/admin/trading_fees/calculate?investor_id=xxx
      # (optional) &period_start=YYYY-MM-DD&period_end=YYYY-MM-DD
      def calculate
        start_date, end_date = extract_period_params

        if start_date && end_date
          ok = validate_period_for_investor!(@investor, start_date, end_date)
          return unless ok

          profit_amount = profits_for(@investor, start_date, end_date)
          existing_fee = TradingFee.active.find_by(investor_id: @investor.id, period_start: start_date, period_end: end_date)

          if existing_fee
            render json: {
              error: 'Trading fee ya aplicado para este período',
              period_start: start_date,
              period_end: end_date,
              profit_amount: profit_amount,
              fee_percentage: existing_fee.fee_percentage,
              fee_amount: existing_fee.fee_amount,
              already_applied: true
            }, status: :conflict
            return
          end

          if profit_amount <= 0
            render json: {
              error: 'No hay ganancias en el período',
              period_start: start_date,
              period_end: end_date,
              profit_amount: 0
            }, status: :unprocessable_entity
            return
          end

          fee_percentage = params[:fee_percentage]&.to_f || 30.0
          fee_amount = (profit_amount * (fee_percentage / 100.0)).round(2)

          render json: {
            investor_id: @investor.id,
            investor_name: @investor.name,
            period_start: start_date,
            period_end: end_date,
            profit_amount: profit_amount,
            fee_percentage: fee_percentage,
            fee_amount: fee_amount,
            current_balance: @investor.portfolio.current_balance,
            balance_after_fee: @investor.portfolio.current_balance - fee_amount,
            already_applied: false
          }
          return
        end

        calculator = TradingFeeCalculator.new(@investor)
        result = calculator.calculate

        existing_fee = TradingFee.active.find_by(
          investor_id: @investor.id,
          period_start: result[:period_start],
          period_end: result[:period_end]
        )

        if existing_fee
          render json: {
            error: 'Trading fee ya aplicado para este período',
            period_start: result[:period_start],
            period_end: result[:period_end],
            profit_amount: result[:profit_amount],
            fee_percentage: existing_fee.fee_percentage,
            fee_amount: existing_fee.fee_amount,
            already_applied: true
          }, status: :conflict
          return
        end

        if result[:profit_amount] <= 0
          render json: {
            error: 'No hay ganancias en el período',
            period_start: result[:period_start],
            period_end: result[:period_end],
            profit_amount: 0
          }, status: :unprocessable_entity
          return
        end

        fee_percentage = params[:fee_percentage]&.to_f || 30.0
        fee_amount = (result[:profit_amount] * (fee_percentage / 100.0)).round(2)

        render json: {
          investor_id: @investor.id,
          investor_name: @investor.name,
          period_start: result[:period_start],
          period_end: result[:period_end],
          profit_amount: result[:profit_amount],
          fee_percentage: fee_percentage,
          fee_amount: fee_amount,
          current_balance: @investor.portfolio.current_balance,
          balance_after_fee: @investor.portfolio.current_balance - fee_amount,
          already_applied: false
        }
      end

      # POST /api/admin/trading_fees
      def create
        fee_percentage = params[:fee_percentage]&.to_f

        if fee_percentage.blank? || fee_percentage <= 0 || fee_percentage > 100
          render_error('El porcentaje debe estar entre 0 y 100', status: :unprocessable_entity)
          return
        end

        start_date, end_date = extract_period_params

        if start_date && end_date
          ok = validate_period_for_investor!(@investor, start_date, end_date)
          return unless ok

          if TradingFee.active.exists?(investor_id: @investor.id, period_start: start_date, period_end: end_date)
            render_error('Trading fee ya aplicado para este período', status: :conflict)
            return
          end

          applicator = TradingFeeApplicator.new(
            @investor,
            fee_percentage: fee_percentage,
            applied_by: current_user,
            notes: params[:notes],
            period_start: start_date,
            period_end: end_date
          )

          if applicator.apply
            fee = TradingFee.where(investor_id: @investor.id, period_start: start_date, period_end: end_date).order(applied_at: :desc).first

            ActivityLogger.log(
              user: current_user,
              target: fee,
              action: 'TRADING_FEE_APPLIED',
              metadata: {
                amount: applicator.fee_amount,
                request_type: 'TRADING_FEE',
                from: @investor.portfolio&.current_balance.to_f,
                to: (@investor.portfolio&.current_balance.to_f - applicator.fee_amount.to_f)
              }
            )

            render json: serialize_trading_fee(fee), status: :created
          else
            render_error(applicator.errors.join(', '), status: :unprocessable_entity)
          end
          return
        end

        # Evitar doble cobro del mismo período (por defecto)
        result = TradingFeeCalculator.new(@investor).calculate
        if TradingFee.active.exists?(investor_id: @investor.id, period_start: result[:period_start], period_end: result[:period_end])
          render_error('Trading fee ya aplicado para este período', status: :conflict)
          return
        end

        applicator = TradingFeeApplicator.new(
          @investor,
          fee_percentage: fee_percentage,
          applied_by: current_user,
          notes: params[:notes]
        )

        if applicator.apply
          fee = TradingFee.where(investor_id: @investor.id).order(applied_at: :desc).first

          ActivityLogger.log(
            user: current_user,
            target: fee,
            action: 'TRADING_FEE_APPLIED',
            metadata: {
              amount: applicator.fee_amount,
              request_type: 'TRADING_FEE',
              from: @investor.portfolio&.current_balance.to_f,
              to: (@investor.portfolio&.current_balance.to_f - applicator.fee_amount.to_f)
            }
          )

          render json: serialize_trading_fee(fee), status: :created
        else
          render_error(applicator.errors.join(', '), status: :unprocessable_entity)
        end
      end

      # PATCH /api/admin/trading_fees/:id
      # Edita una comisión ya aplicada sin re-escribir historia: crea un ajuste contable (PortfolioHistory)
      # por la diferencia y actualiza el balance actual del inversor.
      def update
        return unless @trading_fee

        fee_percentage = params[:fee_percentage]&.to_f
        notes = params[:notes]

        if fee_percentage.blank? || fee_percentage <= 0 || fee_percentage > 100
          render_error('El porcentaje debe estar entre 0 y 100', status: :unprocessable_entity)
          return
        end

        fee = @trading_fee
        investor = fee.investor
        portfolio = investor.portfolio
        unless portfolio
          render_error('Portfolio no encontrado', status: :unprocessable_entity)
          return
        end

        old_fee_amount = fee.fee_amount.to_f
        new_fee_amount = (fee.profit_amount.to_f * (fee_percentage / 100.0)).round(2)
        delta = (new_fee_amount - old_fee_amount).round(2)

        ApplicationRecord.transaction do
          old_fee_percentage = fee.fee_percentage.to_f

          # Always persist the updated fee info, even if delta is 0 (e.g. notes fix).
          fee.update!(
            fee_percentage: fee_percentage,
            fee_amount: new_fee_amount,
            notes: notes
          )

          if delta != 0.0
            new_balance = (portfolio.current_balance.to_f - delta).round(2)
            if new_balance < 0
              fee.errors.add(:base, 'Insufficient balance to apply trading fee adjustment')
              raise ActiveRecord::RecordInvalid, fee
            end

            PortfolioHistory.create!(
              investor: investor,
              event: 'TRADING_FEE_ADJUSTMENT',
              amount: (-delta).round(2), # negative => extra charge, positive => refund
              previous_balance: portfolio.current_balance.to_f,
              new_balance: new_balance,
              status: 'COMPLETED',
              date: Time.current
            )

            portfolio.update!(current_balance: new_balance)
          end

          ActivityLogger.log(
            user: current_user,
            target: fee,
            action: 'TRADING_FEE_UPDATED',
            metadata: {
              old_fee_percentage: old_fee_percentage,
              new_fee_percentage: fee_percentage,
              old_fee_amount: old_fee_amount,
              new_fee_amount: new_fee_amount,
              delta: delta,
              investor_id: investor.id,
              period_start: fee.period_start,
              period_end: fee.period_end
            }
          )
        end

        render json: serialize_trading_fee(fee.reload), status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message, status: :unprocessable_entity)
      rescue StandardError => e
        render_error("Error updating trading fee: #{e.message}", status: :unprocessable_entity)
      end

      # DELETE /api/admin/trading_fees/:id
      # "Elimina" (anula) una comisión aplicada: revierte el impacto en balance con un ajuste contable
      # y marca la comisión como voided para permitir re-aplicar el período si hace falta.
      def destroy
        return unless @trading_fee

        fee = @trading_fee
        if fee.voided_at.present?
          render_error('Trading fee ya fue anulada', status: :conflict)
          return
        end

        investor = fee.investor
        portfolio = investor.portfolio
        unless portfolio
          render_error('Portfolio no encontrado', status: :unprocessable_entity)
          return
        end

        fee_amount = fee.fee_amount.to_f

        ApplicationRecord.transaction do
          new_balance = (portfolio.current_balance.to_f + fee_amount).round(2)

          PortfolioHistory.create!(
            investor: investor,
            event: 'TRADING_FEE_ADJUSTMENT',
            amount: fee_amount.round(2), # refund
            previous_balance: portfolio.current_balance.to_f,
            new_balance: new_balance,
            status: 'COMPLETED',
            date: Time.current
          )

          portfolio.update!(current_balance: new_balance)

          fee.update!(voided_at: Time.current, voided_by: current_user)

          ActivityLogger.log(
            user: current_user,
            target: fee,
            action: 'TRADING_FEE_VOIDED',
            metadata: {
              fee_amount: fee_amount,
              investor_id: investor.id,
              period_start: fee.period_start,
              period_end: fee.period_end
            }
          )
        end

        render json: serialize_trading_fee(fee.reload), status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message, status: :unprocessable_entity)
      rescue StandardError => e
        render_error("Error voiding trading fee: #{e.message}", status: :unprocessable_entity)
      end

      # GET /api/admin/trading_fees/investors_summary
      # optional: ?period_start=YYYY-MM-DD&period_end=YYYY-MM-DD
      def investors_summary
        investors = Investor.where(status: 'ACTIVE').includes(:portfolio)

        start_date, end_date = extract_period_params

        summary = investors.map do |investor|
          if start_date && end_date
            invested = invested_amount_at(investor, end_date)
            next if invested <= 0

            profit_amount = profits_for(investor, start_date, end_date)
            existing_fee = TradingFee.active.find_by(investor_id: investor.id, period_start: start_date, period_end: end_date)

            {
              investor_id: investor.id,
              investor_name: investor.name,
              investor_email: investor.email,
              trading_fee_frequency: investor.trading_fee_frequency,
              current_balance: investor.portfolio&.current_balance || 0,
              period_start: start_date,
              period_end: end_date,
              profit_amount: profit_amount,
              has_profit: profit_amount > 0,
              already_applied: !!existing_fee,
              applied_fee_id: existing_fee&.id,
              applied_fee_amount: existing_fee&.fee_amount&.to_f,
              applied_fee_percentage: existing_fee&.fee_percentage&.to_f,
              monthly_profits: monthly_breakdown_for(investor, start_date, end_date)
            }
          else
            calculator = TradingFeeCalculator.new(investor)
            result = calculator.calculate

            invested = invested_amount_at(investor, result[:period_end])
            next if invested <= 0

            existing_fee = TradingFee.active.find_by(
              investor_id: investor.id,
              period_start: result[:period_start],
              period_end: result[:period_end]
            )

            {
              investor_id: investor.id,
              investor_name: investor.name,
              investor_email: investor.email,
              trading_fee_frequency: investor.trading_fee_frequency,
              current_balance: investor.portfolio&.current_balance || 0,
              period_start: result[:period_start],
              period_end: result[:period_end],
              profit_amount: result[:profit_amount],
              has_profit: result[:profit_amount] > 0,
              already_applied: !!existing_fee,
              applied_fee_id: existing_fee&.id,
              applied_fee_amount: existing_fee&.fee_amount&.to_f,
              applied_fee_percentage: existing_fee&.fee_percentage&.to_f,
              monthly_profits: monthly_breakdown_for(investor, result[:period_start], result[:period_end])
            }
          end
        end

        summary = summary.compact

        render json: summary
      end

      private

      def set_investor
        investor_id = params[:investor_id] || params[:id]
        @investor = Investor.includes(:portfolio).find_by(id: investor_id)

        unless @investor
          render_error('Inversor no encontrado', status: :not_found)
        end
      end

      def set_trading_fee
        @trading_fee = TradingFee.includes(:investor).find_by(id: params[:id])
        return if @trading_fee

        render_error('Trading fee no encontrado', status: :not_found)
      end

      def extract_period_params
        return [nil, nil] unless params[:period_start].present? && params[:period_end].present?

        start_date = Date.parse(params[:period_start].to_s)
        end_date = Date.parse(params[:period_end].to_s)
        [start_date, end_date]
      rescue ArgumentError
        [nil, nil]
      end

      def validate_period_for_investor!(investor, start_date, end_date)
        return true if investor.blank? || start_date.blank? || end_date.blank?
        return true unless investor.respond_to?(:trading_fee_frequency) && investor.trading_fee_frequency == 'ANNUAL'

        expected_start = start_date.beginning_of_year.to_date
        expected_end = start_date.end_of_year.to_date

        if start_date != expected_start || end_date != expected_end
          render_error('Este inversor está configurado como ANNUAL: el período debe ser un año calendario completo', status: :unprocessable_entity)
          return false
        end

        true
      end

      def monthly_breakdown_for(investor, start_date, end_date)
        return [] if start_date.blank? || end_date.blank?

        start_date = start_date.to_date
        end_date = end_date.to_date
        range = start_date.beginning_of_day..end_date.end_of_day

        grouped = PortfolioHistory.where(investor_id: investor.id)
                                 .where(event: 'OPERATING_RESULT', status: 'COMPLETED')
                                 .where(date: range)
                                 .group("DATE_TRUNC('month', date)")
                                 .sum(:amount)

        months_between(start_date, end_date).map do |m|
          key = Time.utc(m.year, m.month, 1)
          amount = grouped[key]&.to_f || 0.0
          { month: m.strftime('%Y-%m'), amount: amount }
        end
      end

      def months_between(start_date, end_date)
        return [] if start_date.blank? || end_date.blank?

        start_m = start_date.to_date.beginning_of_month
        end_m = end_date.to_date.beginning_of_month
        months = []
        cur = start_m
        while cur <= end_m
          months << cur
          cur = (cur >> 1)
        end
        months
      end

      def invested_amount_at(investor, at_date)
        return 0.0 if at_date.blank?

        range = ..at_date.to_date.end_of_day

        deposits = PortfolioHistory.where(investor_id: investor.id)
                                  .where(event: 'DEPOSIT', status: 'COMPLETED')
                                  .where(date: range)
                                  .sum(:amount)
                                  .to_f

        withdrawals = PortfolioHistory.where(investor_id: investor.id)
                                     .where(event: 'WITHDRAWAL', status: 'COMPLETED')
                                     .where(date: range)
                                     .sum(:amount)
                                     .to_f

        (deposits - withdrawals).round(2)
      end

      def profits_for(investor, start_date, end_date)
        range = start_date.to_date.beginning_of_day..end_date.to_date.end_of_day

        PortfolioHistory.where(investor_id: investor.id)
                       .where(event: 'OPERATING_RESULT', status: 'COMPLETED')
                       .where(date: range)
                       .sum(:amount)
                       .to_f
      end

      def serialize_trading_fee(fee)
        {
          id: fee.id,
          investor_id: fee.investor_id,
          investor_name: fee.investor.name,
          investor_email: fee.investor.email,
          applied_by_id: fee.applied_by_id,
          applied_by_name: fee.applied_by.name,
          period_start: fee.period_start,
          period_end: fee.period_end,
          profit_amount: fee.profit_amount,
          fee_percentage: fee.fee_percentage,
          fee_amount: fee.fee_amount,
          notes: fee.notes,
          applied_at: fee.applied_at,
          voided_at: fee.voided_at,
          voided_by_id: fee.voided_by_id,
          created_at: fee.created_at
        }
      end
    end
  end
end
