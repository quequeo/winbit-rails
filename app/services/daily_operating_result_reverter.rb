require 'bigdecimal'

# Reverts one applied daily operating result (inverse of DailyOperatingResultApplicator):
# - Restores strategy_return_* compounding
# - Deletes OPERATING_RESULT portfolio_histories for that movement time
# - Deletes the DailyOperatingResult row
# - Runs PortfolioRecalculator for affected investors
#
# There is no admin UI for this; use `bin/rails operating:revert_daily` (see task).
class DailyOperatingResultReverter
  Result = Struct.new(:ok, :error, :preview, keyword_init: true)

  def self.movement_time_for_date(date)
    Time.zone.local(date.year, date.month, date.day, 17, 0, 0)
  end

  def self.run!(date:, dry_run: false)
    dor = DailyOperatingResult.find_by(date: date)
    return Result.new(ok: false, error: "No hay operativa diaria para #{date}") unless dor

    percent = BigDecimal(dor.percent.to_s)
    factor = (BigDecimal('1') + (percent / 100))
    at_time = movement_time_for_date(date)

    ph_scope = PortfolioHistory.where(
      event: 'OPERATING_RESULT',
      status: 'COMPLETED',
      date: at_time,
    )

    rows = ph_scope.includes(:investor).map do |ph|
      {
        ph: ph,
        investor: ph.investor,
        delta: BigDecimal(ph.amount.to_s),
      }
    end

    if rows.empty?
      return Result.new(
        ok: false,
        error: "No hay movimientos OPERATING_RESULT en #{at_time.iso8601} (¿zona horaria?). Revisá la fecha.",
      )
    end

    preview = {
      date: date,
      percent: percent.to_f,
      movement_at: at_time.iso8601,
      investors: rows.size,
      daily_operating_result_id: dor.id,
    }

    return Result.new(ok: true, preview: preview) if dry_run

    investor_ids = rows.map { |r| r[:investor].id }.uniq
    investors = Investor.where(id: investor_ids).index_by(&:id)

    ApplicationRecord.transaction do
      rows.each do |r|
        inv = r[:investor]
        delta = r[:delta]
        portfolio = inv.portfolio
        next unless portfolio

        attrs = {}
        if portfolio.strategy_return_all_percent.present?
          new_pct = BigDecimal(portfolio.strategy_return_all_percent.to_s)
          old_pct = (((BigDecimal('1') + (new_pct / 100)) / factor) - BigDecimal('1')) * 100
          attrs[:strategy_return_all_percent] = old_pct.round(4, :half_up).to_f
          all_usd = portfolio.strategy_return_all_usd.nil? ? BigDecimal('0') : BigDecimal(portfolio.strategy_return_all_usd.to_s)
          attrs[:strategy_return_all_usd] = (all_usd - delta).round(2, :half_up).to_f
        end

        if portfolio.strategy_return_ytd_percent.present?
          new_y = BigDecimal(portfolio.strategy_return_ytd_percent.to_s)
          old_y = (((BigDecimal('1') + (new_y / 100)) / factor) - BigDecimal('1')) * 100
          attrs[:strategy_return_ytd_percent] = old_y.round(4, :half_up).to_f
          ytd_usd = portfolio.strategy_return_ytd_usd.nil? ? BigDecimal('0') : BigDecimal(portfolio.strategy_return_ytd_usd.to_s)
          attrs[:strategy_return_ytd_usd] = (ytd_usd - delta).round(2, :half_up).to_f
        end

        portfolio.update!(attrs) if attrs.any?
      end

      ph_scope.delete_all
      dor.destroy!

      investor_ids.each do |iid|
        PortfolioRecalculator.recalculate!(investors[iid])
      end
    end

    Result.new(ok: true, preview: preview)
  end
end
