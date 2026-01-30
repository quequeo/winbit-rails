require 'bigdecimal'

# Applies a manual referral commission (credit) to an investor.
#
# Why a PortfolioHistory event?
# - It is auditable (ledger)
# - It updates portfolio balance consistently
# - It is visible in public history and the portal chart
#
# Supports backfilling by date:
# - If the commission date is in the past and there are movements after it,
#   we create the history record at that date and then run PortfolioRecalculator.
class ReferralCommissionApplicator
  attr_reader :investor, :amount, :applied_by, :applied_at, :errors

  def initialize(investor, amount:, applied_by:, applied_at: nil)
    @investor = investor
    @amount = amount
    @applied_by = applied_by
    @applied_at = normalize_applied_at(applied_at) || Time.current
    @errors = []
  end

  def apply
    validate_inputs
    return false if errors.any?

    portfolio = investor.portfolio || Portfolio.create!(investor: investor)

    has_future_history =
      PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED')
                      .where('date > ?', applied_at)
                      .exists?

    ApplicationRecord.transaction do
      if has_future_history
        # Backfill: create at applied_at and rebuild balances from full history.
        last = PortfolioHistory.where(investor_id: investor.id, status: 'COMPLETED')
                               .where('date <= ?', applied_at)
                               .order(date: :desc, created_at: :desc)
                               .first

        previous_balance = bd(last ? last.new_balance : portfolio.current_balance)
        new_balance = (previous_balance + bd(amount)).round(2, :half_up)

        PortfolioHistory.create!(
          investor: investor,
          event: 'REFERRAL_COMMISSION',
          amount: bd(amount).to_f,
          previous_balance: previous_balance.to_f,
          new_balance: new_balance.to_f,
          status: 'COMPLETED',
          date: applied_at
        )

        PortfolioRecalculator.recalculate!(investor)
      else
        # Normal case: apply incrementally using current portfolio snapshot.
        previous_balance = bd(portfolio.current_balance)
        new_balance = (previous_balance + bd(amount)).round(2, :half_up)

        PortfolioHistory.create!(
          investor: investor,
          event: 'REFERRAL_COMMISSION',
          amount: bd(amount).to_f,
          previous_balance: previous_balance.to_f,
          new_balance: new_balance.to_f,
          status: 'COMPLETED',
          date: applied_at
        )

        portfolio.update!(current_balance: new_balance.to_f)
      end
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.record.errors.full_messages.join(', ')
    false
  rescue StandardError => e
    @errors << "Error applying referral commission: #{e.message}"
    Rails.logger.error("ReferralCommissionApplicator Error: #{e.message}\n#{e.backtrace.join("\n")}")
    false
  end

  private

  def bd(n)
    BigDecimal(n.to_s)
  end

  def validate_inputs
    if investor.blank?
      @errors << 'Investor is required'
    elsif !investor.status_active?
      @errors << 'Investor must be active'
    end

    if applied_by.blank?
      @errors << 'Applied by user is required'
    end

    a = bd(amount)
    if a <= 0
      @errors << 'Amount must be greater than 0'
    end
  rescue ArgumentError
    @errors << 'Amount is invalid'
  end

  # Accepts:
  # - nil (defaults to now)
  # - "YYYY-MM-DD" (interpreted as 19:00 local time to preserve ordering after daily operating at 17:00)
  # - ISO datetime string
  # - Time
  def normalize_applied_at(value)
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
