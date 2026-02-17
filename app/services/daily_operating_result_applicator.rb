require 'bigdecimal'

class DailyOperatingResultApplicator
  attr_reader :date, :percent, :applied_by, :notes, :errors

  def initialize(date:, percent:, applied_by:, notes: nil)
    @date = date
    @percent = BigDecimal(percent.to_s)
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
      percent: percent.to_f,
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

    ApplicationRecord.transaction do
      DailyOperatingResult.create!(
        date: date,
        percent: percent,
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
    (balance_before * (percent / 100)).round(2, :half_up)
  end


  def movement_time
    # Operativa: antes de las 18hs (para quedar ordenado antes de depósitos/retiros del día)
    Time.zone.local(date.year, date.month, date.day, 17, 0, 0)
  end
end
