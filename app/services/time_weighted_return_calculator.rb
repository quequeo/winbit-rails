require 'bigdecimal'

# Computes Time-Weighted Return (TWR) and P&L (USD) for:
# - a single investor (using PortfolioHistory)
# - the whole platform (aggregating all investors, replaying PortfolioHistory in time order)
#
# External flows (do NOT change return, but split sub-periods):
# - DEPOSIT, WITHDRAWAL
#
# Internal performance (DO change return, does NOT split):
# - OPERATING_RESULT, TRADING_FEE, etc.
#
# Trading fees reduce return automatically because they reduce balances (internal performance).
class TimeWeightedReturnCalculator
  Result = Struct.new(
    :twr_percent,
    :pnl_usd,
    :start_value,
    :end_value,
    :net_flows_usd,
    :effective_start_at,
    keyword_init: true
  )

  FLOW_EVENTS = %w[DEPOSIT WITHDRAWAL].freeze

  def self.for_investor(investor_id:, from:, to: Time.current)
    new(from: from, to: to).compute_for_investor(investor_id: investor_id)
  end

  def self.for_platform(from:, to: Time.current)
    new(from: from, to: to).compute_for_platform
  end

  def initialize(from:, to:)
    @from = from
    @to = to
  end

  def compute_for_investor(investor_id:)
    range_start = from || Time.at(0)
    range_end = to || Time.current

    initial_value = last_balance_before(investor_id: investor_id, time: range_start)

    histories = PortfolioHistory
                .where(status: 'COMPLETED', investor_id: investor_id)
                .where(date: range_start..range_end)
                .order(:date, :created_at)

    # If there is no history, fall back to the current portfolio snapshot (0% return).
    if histories.empty?
      current = Portfolio.where(investor_id: investor_id).limit(1).pick(:current_balance)
      current = current ? bd(current) : bd('0')
      eff = current.positive? ? range_start : nil
      return Result.new(
        twr_percent: 0.0,
        pnl_usd: 0.0,
        start_value: round2(current).to_f,
        end_value: round2(current).to_f,
        net_flows_usd: 0.0,
        effective_start_at: eff
      )
    end

    product = bd('1')
    running = initial_value
    period_start_value = initial_value
    pnl_start_value = initial_value
    net_flows = bd('0')
    effective_start_at = initial_value.positive? ? range_start : nil

    histories.each do |h|
      before = running
      after = bd(h.new_balance)

      if FLOW_EVENTS.include?(h.event)
        # End sub-period right BEFORE the flow is applied
        if period_start_value.positive?
          r = (before - period_start_value) / period_start_value
          product *= (bd('1') + r)
        end

        # Count flows only after we started (so the very first deposit that starts the strategy isn't counted)
        if effective_start_at
          amt = bd(h.amount).abs
          net_flows += (h.event == 'DEPOSIT' ? amt : -amt)
        end

        # Apply the flow and start next sub-period AFTER the flow
        running = after

        if effective_start_at.nil? && running.positive?
          effective_start_at = h.date
          pnl_start_value = running
        end

        period_start_value = running
        next
      end

      # Internal performance (including TRADING_FEE) just updates running value
      running = after
    end

    # Final sub-period until the end of the window
    if period_start_value.positive?
      r = (running - period_start_value) / period_start_value
      product *= (bd('1') + r)
    end

    twr = (product - bd('1')) * 100
    pnl = running - pnl_start_value - net_flows

    Result.new(
      twr_percent: twr.to_f,
      pnl_usd: round2(pnl).to_f,
      start_value: round2(pnl_start_value).to_f,
      end_value: round2(running).to_f,
      net_flows_usd: round2(net_flows).to_f,
      effective_start_at: effective_start_at
    )
  end

  def compute_for_platform
    range_start = from || Time.at(0)
    range_end = to || Time.current

    # Initialize per-investor balances at range start (strictly before start, then we replay within range)
    investor_ids = Portfolio.distinct.pluck(:investor_id)

    # If there is no history at all, fall back to the current AUM snapshot (0% return).
    unless PortfolioHistory.where(status: 'COMPLETED').exists?
      current = bd(Portfolio.sum(:current_balance))
      eff = current.positive? ? range_start : nil
      return Result.new(
        twr_percent: 0.0,
        pnl_usd: 0.0,
        start_value: round2(current).to_f,
        end_value: round2(current).to_f,
        net_flows_usd: 0.0,
        effective_start_at: eff
      )
    end

    balances = {}
    total = bd('0')

    if investor_ids.any?
      initial_rows = PortfolioHistory
                     .where(status: 'COMPLETED', investor_id: investor_ids)
                     .where('date < ?', range_start)
                     .select('DISTINCT ON (investor_id) investor_id, new_balance')
                     .order('investor_id, date DESC, created_at DESC')

      initial_rows.each do |r|
        b = bd(r.new_balance)
        balances[r.investor_id] = b
        total += b
      end
    end

    histories = PortfolioHistory
                .where(status: 'COMPLETED', investor_id: investor_ids)
                .where(date: range_start..range_end)
                .order(:date, :created_at)

    product = bd('1')
    running_total = total
    period_start_value = running_total
    pnl_start_value = running_total
    net_flows = bd('0')
    effective_start_at = running_total.positive? ? range_start : nil

    histories.each do |h|
      before_total = running_total

      old = balances[h.investor_id] || bd('0')
      newb = bd(h.new_balance)

      if FLOW_EVENTS.include?(h.event)
        # End sub-period right BEFORE the flow is applied
        if period_start_value.positive?
          r = (before_total - period_start_value) / period_start_value
          product *= (bd('1') + r)
        end

        if effective_start_at
          amt = bd(h.amount).abs
          net_flows += (h.event == 'DEPOSIT' ? amt : -amt)
        end

        # Apply this investor balance change (flow) into total
        balances[h.investor_id] = newb
        running_total += (newb - old)

        if effective_start_at.nil? && running_total.positive?
          effective_start_at = h.date
          pnl_start_value = running_total
        end

        period_start_value = running_total
        next
      end

      # Internal performance: update balances + total
      balances[h.investor_id] = newb
      running_total += (newb - old)
    end

    if period_start_value.positive?
      r = (running_total - period_start_value) / period_start_value
      product *= (bd('1') + r)
    end

    twr = (product - bd('1')) * 100
    pnl = running_total - pnl_start_value - net_flows

    Result.new(
      twr_percent: twr.to_f,
      pnl_usd: round2(pnl).to_f,
      start_value: round2(pnl_start_value).to_f,
      end_value: round2(running_total).to_f,
      net_flows_usd: round2(net_flows).to_f,
      effective_start_at: effective_start_at
    )
  end

  private

  attr_reader :from, :to

  def bd(n)
    BigDecimal(n.to_s)
  end

  def round2(x)
    bd(x).round(2, :half_up)
  end

  def last_balance_before(investor_id:, time:)
    val = PortfolioHistory
          .where(status: 'COMPLETED', investor_id: investor_id)
          .where('date < ?', time)
          .order(date: :desc, created_at: :desc)
          .limit(1)
          .pick(:new_balance)
    val ? bd(val) : bd('0')
  end
end
