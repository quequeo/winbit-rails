# frozen_string_literal: true

require 'bigdecimal'

# Vpcust-style pending profit for withdrawal fee preview and approval.
# Uses the latest fee-reset anchor between PortfolioHistory (WITHDRAWAL / TRADING_FEE)
# and an optional Genesis sheet snapshot on the portfolio.
class InvestorPendingProfit
  def self.pending_until(investor:, as_of:, current_balance:)
    new(investor: investor, as_of: as_of, current_balance: current_balance).compute_pending
  end

  # Returns { vpcust: BigDecimal, reset_at: Time|ActiveSupport::TimeWithZone|nil } for logging / support.
  def self.fee_reset_snapshot(investor:, as_of:)
    vpcust, reset_at = new(investor: investor, as_of: as_of, current_balance: BigDecimal('0')).send(:effective_reset)
    { vpcust: vpcust, reset_at: reset_at }
  end

  def initialize(investor:, as_of:, current_balance:)
    @investor = investor
    @as_of = as_of
    @current_balance = BigDecimal(current_balance.to_s)
  end

  def compute_pending
    vpcust, reset_at = effective_reset
    inflows = inflows_since(reset_at)
    pending = @current_balance - vpcust - inflows
    pending.positive? ? pending : BigDecimal('0')
  end

  private

  def effective_reset
    portfolio = @investor.portfolio

    history_reset = PortfolioHistory
                      .where(investor_id: @investor.id, event: %w[TRADING_FEE WITHDRAWAL], status: 'COMPLETED')
                      .where('date <= ?', @as_of)
                      .order(date: :desc, created_at: :desc)
                      .first

    genesis_at = portfolio&.genesis_fee_basis_at
    genesis_v = portfolio&.genesis_vpcust_usd

    genesis_candidate =
      if genesis_at.present? && genesis_v.present?
        { at: genesis_at, balance: BigDecimal(genesis_v.to_s) }
      end

    history_candidate =
      if history_reset
        { at: history_reset.date, balance: BigDecimal(history_reset.new_balance.to_s) }
      end

    candidates = []
    candidates << genesis_candidate if genesis_candidate
    candidates << history_candidate if history_candidate
    chosen = candidates.max_by { |c| c[:at] }

    if chosen
      [chosen[:balance], chosen[:at]]
    else
      [BigDecimal('0'), nil]
    end
  end

  def inflows_since(reset_at)
    if reset_at
      PortfolioHistory
        .where(investor_id: @investor.id, event: %w[DEPOSIT REFERRAL_COMMISSION], status: 'COMPLETED')
        .where('date > ? AND date <= ?', reset_at, @as_of)
        .sum(:amount)
    else
      PortfolioHistory
        .where(investor_id: @investor.id, event: %w[DEPOSIT REFERRAL_COMMISSION], status: 'COMPLETED')
        .where('date <= ?', @as_of)
        .sum(:amount)
    end
  end
end
