require 'bigdecimal'

class DailyOperatingResultApplicator
  attr_reader :date, :applied_by, :notes, :errors

  def percent
    resolved_percent
  end

  def initialize(date:, applied_by:, notes: nil, percent: nil, amount_usd: nil)
    @date = date
    @percent_param = percent
    @amount_usd_param = amount_usd
    @percent = nil
    @percent_resolved = false
    @percent_derived_from_amount_usd = false
    @applied_by = applied_by
    @notes = notes
    @errors = []
  end

  def preview
    validate_inputs
    return nil if errors.any?

    at_time = movement_time
    investors = eligible_investors(at_time: at_time)

    rows = investors.map do |inv|
      before = balance_at(inv.id, at_time)
      delta = daily_delta(before)
      after = (before + delta).round(2, :half_up)

      {
        investor_id: inv.id,
        investor_name: inv.name,
        investor_email: inv.email,
        balance_before: before.to_f,
        delta: delta.to_f,
        balance_after: after.to_f,
      }
    end

    total_before = rows.sum { |r| r[:balance_before] }
    total_delta = rows.sum { |r| r[:delta] }
    total_after = rows.sum { |r| r[:balance_after] }

    {
      date: date,
      percent: resolved_percent.to_f,
      amount_usd: derived_amount_usd,
      percent_derived_from_amount_usd: @percent_derived_from_amount_usd,
      investors_count: rows.size,
      total_before: total_before,
      total_delta: total_delta,
      total_after: total_after,
      investors: rows,
    }
  end

  def apply
    validate_inputs
    return false if errors.any?

    at_time = movement_time
    investors = eligible_investors(at_time: at_time)
    if investors.empty?
      @errors << 'No hay inversores activos con capital para esa fecha'
      return false
    end

    msg = PortfolioRecalculator.negative_total_invested_blocking_message(investors)
    @errors << ('No se puede aplicar: ' + msg) if msg
    return false if errors.any?

    ApplicationRecord.transaction do
      DailyOperatingResult.create!(
        date: date,
        percent: resolved_percent,
        applied_by: applied_by,
        applied_at: Time.current,
        notes: notes,
      )

      investors.each do |inv|
        before = balance_at(inv.id, at_time)
        delta = daily_delta(before)
        after = (before + delta).round(2, :half_up)

        PortfolioHistory.create!(
          investor_id: inv.id,
          event: 'OPERATING_RESULT',
          amount: delta.to_f,
          previous_balance: before.to_f,
          new_balance: after.to_f,
          status: 'COMPLETED',
          date: at_time,
        )

        PortfolioRecalculator.recalculate!(inv)
        compound_strategy_returns!(inv, delta)
      end
    end

    true
  rescue StandardError => e
    @errors << e.message
    Rails.logger.error("DailyOperatingResultApplicator error: #{e.message}\n#{e.backtrace.join("\n")}")
    false
  end

  private

  def validate_inputs
    @errors << 'Date is required' if date.blank?
    @errors << 'Applied by user is required' if applied_by.blank?
    @errors << 'No se puede cargar operativa diaria con fecha futura' if date.present? && date > Date.current

    # No duplicados
    if date.present? && DailyOperatingResult.exists?(date: date)
      @errors << 'Ya existe operativa diaria cargada para esa fecha'
    end

    resolve_percent!
  end

  def resolve_percent!
    return resolved_percent if @percent_resolved

    @percent_resolved = true

    if @percent_param.present? && @amount_usd_param.present?
      @errors << 'Indicá porcentaje o monto en USD, no ambos'
      return nil
    end

    if @amount_usd_param.present?
      amount = BigDecimal(@amount_usd_param.to_s)
      capital = total_capital_at_close
      if capital <= 0
        @errors << 'No hay capital total para calcular el porcentaje'
        return nil
      end

      @percent = (amount / capital * 100).round(6, :half_up)
      @percent_derived_from_amount_usd = true
      return @percent
    end

    if @percent_param.present?
      @percent = BigDecimal(@percent_param.to_s)
      return @percent
    end

    @errors << 'Indicá el porcentaje o el monto en USD'
    nil
  end

  def resolved_percent
    resolve_percent! unless @percent_resolved
    @percent
  end

  def derived_amount_usd
    return nil unless @amount_usd_param.present?

    BigDecimal(@amount_usd_param.to_s).to_f
  end

  def total_capital_at_close
    at_time = movement_time
    eligible_investors(at_time: at_time).sum { |inv| balance_at(inv.id, at_time) }
  end

  def eligible_investors(at_time:)
    Investor.where(status: 'ACTIVE').includes(:portfolio).select do |inv|
      bal = balance_at(inv.id, at_time)
      bal > 0
    end
  end

  def balance_at(investor_id, at_time)
    last = PortfolioHistory.where(investor_id: investor_id)
                           .where(status: 'COMPLETED')
                           .where('date <= ?', at_time)
                           .order(date: :desc, created_at: :desc)
                           .first
    last ? BigDecimal(last.new_balance.to_s) : BigDecimal('0')
  end

  def daily_delta(balance_before)
    (balance_before * (resolved_percent / 100)).round(2, :half_up)
  end


  def compound_strategy_returns!(investor, delta)
    portfolio = investor.portfolio
    return unless portfolio
    return if portfolio.strategy_return_all_percent.nil? && portfolio.strategy_return_ytd_percent.nil?

    daily_factor = BigDecimal('1') + (resolved_percent / 100)

    if portfolio.strategy_return_all_percent.present?
      old_all_pct = BigDecimal(portfolio.strategy_return_all_percent.to_s)
      new_all_pct = ((BigDecimal('1') + old_all_pct / 100) * daily_factor - BigDecimal('1')) * 100
      prev_all_usd = portfolio.strategy_return_all_usd.nil? ? BigDecimal('0') : BigDecimal(portfolio.strategy_return_all_usd.to_s)
      new_all_usd = prev_all_usd + BigDecimal(delta.to_s)

      portfolio.update!(
        strategy_return_all_percent: new_all_pct.round(4, :half_up).to_f,
        strategy_return_all_usd: new_all_usd.round(2, :half_up).to_f,
      )
    end

    if portfolio.strategy_return_ytd_percent.present?
      old_ytd_pct = BigDecimal(portfolio.strategy_return_ytd_percent.to_s)
      new_ytd_pct = ((BigDecimal('1') + old_ytd_pct / 100) * daily_factor - BigDecimal('1')) * 100
      prev_ytd_usd = portfolio.strategy_return_ytd_usd.nil? ? BigDecimal('0') : BigDecimal(portfolio.strategy_return_ytd_usd.to_s)
      new_ytd_usd = prev_ytd_usd + BigDecimal(delta.to_s)

      portfolio.update!(
        strategy_return_ytd_percent: new_ytd_pct.round(4, :half_up).to_f,
        strategy_return_ytd_usd: new_ytd_usd.round(2, :half_up).to_f,
      )
    end
  end

  def movement_time
    Time.zone.local(date.year, date.month, date.day, 17, 0, 0)
  end
end
