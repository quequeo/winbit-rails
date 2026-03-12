require 'bigdecimal'

class DailyOperatingResultEditor
  attr_reader :result, :new_percent, :edited_by, :notes, :errors

  def initialize(result:, new_percent:, edited_by:, notes: nil)
    @result = result
    @new_percent = BigDecimal(new_percent.to_s)
    @edited_by = edited_by
    @notes = notes
    @errors = []
  end

  def preview
    validate_inputs
    return nil if errors.any?

    at_time = movement_time
    affected = PortfolioHistory.where(event: 'OPERATING_RESULT', status: 'COMPLETED', date: at_time)
                               .includes(investor: :portfolio)

    rows = affected.map do |ph|
      old_delta = BigDecimal(ph.amount.to_s)
      new_delta = (BigDecimal(ph.previous_balance.to_s) * (new_percent / 100)).round(2, :half_up)
      {
        investor_id: ph.investor_id,
        investor_name: ph.investor&.name,
        investor_email: ph.investor&.email,
        old_delta: old_delta.to_f,
        new_delta: new_delta.to_f,
        difference: (new_delta - old_delta).to_f,
      }
    end

    {
      date: result.date,
      old_percent: result.percent.to_f,
      new_percent: new_percent.to_f,
      investors_count: rows.size,
      total_old_delta: rows.sum { |r| r[:old_delta] },
      total_new_delta: rows.sum { |r| r[:new_delta] },
      total_difference: rows.sum { |r| r[:difference] },
      investors: rows,
    }
  end

  def apply
    validate_inputs
    return false if errors.any?

    old_percent = result.percent.to_f

    at_time = movement_time
    affected = PortfolioHistory.where(event: 'OPERATING_RESULT', status: 'COMPLETED', date: at_time)
    investor_ids = affected.pluck(:investor_id).uniq

    if investor_ids.empty?
      @errors << 'No hay movimientos de operativa para esa fecha'
      return false
    end

    ApplicationRecord.transaction do
      result.update!(percent: new_percent, notes: notes.nil? ? result.notes : notes)

      affected.each do |ph|
        new_delta = (BigDecimal(ph.previous_balance.to_s) * (new_percent / 100)).round(2, :half_up)
        new_balance = (BigDecimal(ph.previous_balance.to_s) + new_delta).round(2, :half_up)
        ph.update!(amount: new_delta.to_f, new_balance: new_balance.to_f)
      end

      investor_ids.each do |inv_id|
        investor = Investor.find(inv_id)
        PortfolioRecalculator.recalculate!(investor)
      end
    end

    ActivityLogger.log(
      user: edited_by,
      action: 'edit_daily_operating_result',
      target: result,
      metadata: { from: old_percent, to: new_percent.to_f }
    )

    true
  rescue StandardError => e
    @errors << e.message
    Rails.logger.error("DailyOperatingResultEditor error: #{e.message}\n#{e.backtrace.join("\n")}")
    false
  end

  private

  def validate_inputs
    @errors << 'Result is required' if result.blank?
    @errors << 'Edited by user is required' if edited_by.blank?

    if result.present? && result.date != Date.current
      @errors << 'Solo se puede editar la operativa del día actual'
    end

    if new_percent == BigDecimal(result.percent.to_s)
      @errors << 'El nuevo porcentaje es igual al actual'
    end
  end

  def movement_time
    Time.zone.local(result.date.year, result.date.month, result.date.day, 17, 0, 0)
  end
end
