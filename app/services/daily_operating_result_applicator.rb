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

    ApplicationRecord.transaction do
      DailyOperatingResult.create!(
        date: date,
        percent: percent,
        applied_by: applied_by,
        applied_at: Time.current,
        notes: notes,
      )

      at_time = movement_time
      eligible_investors(at_time: at_time).each do |inv|
        portfolio = inv.portfolio
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

        recalculate_portfolio!(inv)
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


  def recalculate_portfolio!(investor)
    portfolio = investor.portfolio || Portfolio.create!(investor: investor)

    histories = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED')
                              .order(:date, :created_at)

    running = BigDecimal('0')
    histories.each do |h|
      prev = running

      amt = BigDecimal(h.amount.to_s)
      delta =
        case h.event
        when 'WITHDRAWAL'
          -amt.abs
        when 'TRADING_FEE'
          -amt.abs
        else
          amt
        end

      running = (running + delta).round(2, :half_up)
      h.update!(previous_balance: prev.to_f, new_balance: running.to_f)
    end

    deposits_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'DEPOSIT').sum(:amount)
    withdrawals_sum = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED', event: 'WITHDRAWAL').sum(:amount)
    total_invested = (BigDecimal(deposits_sum.to_s) - BigDecimal(withdrawals_sum.to_s)).round(2, :half_up)

    accumulated_return_usd = (running - total_invested).round(2, :half_up)
    accumulated_return_percent = total_invested.positive? ? ((accumulated_return_usd / total_invested) * 100).round(4, :half_up) : BigDecimal('0')

    portfolio.update!(
      current_balance: running.to_f,
      total_invested: total_invested.to_f,
      accumulated_return_usd: accumulated_return_usd.to_f,
      accumulated_return_percent: accumulated_return_percent.to_f,
    )
  end

  def movement_time
    # Operativa: antes de las 18hs (para quedar ordenado antes de depósitos/retiros del día)
    Time.zone.local(date.year, date.month, date.day, 17, 0, 0)
  end
end
