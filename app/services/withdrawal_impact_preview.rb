# frozen_string_literal: true

require 'bigdecimal'

# Preview of post-withdrawal balance including CST/trading fee on pending profit.
# Same fee basis as Api::Public::InvestorsController#withdrawal_fee_preview and
# Requests::Approve#calculate_and_apply_withdrawal_fee.
class WithdrawalImpactPreview
  Result = Struct.new(
    :current_balance,
    :requested_amount,
    :fee_amount,
    :fee_percentage,
    :pending_profit,
    :realized_profit,
    :balance_after,
    :has_fee,
    :computable,
    keyword_init: true
  ) do
    def has_fee?
      has_fee
    end

    def computable?
      computable
    end
  end

  def self.call(investor:, amount:, as_of: Time.current)
    new(investor: investor, amount: amount, as_of: as_of).call
  end

  def initialize(investor:, amount:, as_of:)
    @investor = investor
    @amount = BigDecimal(amount.to_s)
    @as_of = as_of
  end

  def call
    portfolio = @investor.portfolio
    unless portfolio
      return Result.new(
        current_balance: BigDecimal('0'),
        requested_amount: @amount,
        fee_amount: BigDecimal('0'),
        fee_percentage: BigDecimal(@investor.trading_fee_percentage.to_s),
        pending_profit: BigDecimal('0'),
        realized_profit: BigDecimal('0'),
        balance_after: nil,
        has_fee: false,
        computable: false
      )
    end

    current_balance = BigDecimal(portfolio.current_balance.to_s)
    fee_percentage = BigDecimal(@investor.trading_fee_percentage.to_s)
    pending_profit = InvestorPendingProfit.pending_until(
      investor: @investor,
      as_of: @as_of,
      current_balance: current_balance
    )

    realized_profit = BigDecimal('0')
    fee_amount = BigDecimal('0')
    if pending_profit.positive?
      realized_profit = pending_profit
      fee_amount = (realized_profit * (fee_percentage / 100)).round(2, :half_up)
    end

    balance_after = (current_balance - @amount - fee_amount).round(2, :half_up)

    Result.new(
      current_balance: current_balance,
      requested_amount: @amount,
      fee_amount: fee_amount,
      fee_percentage: fee_percentage,
      pending_profit: pending_profit,
      realized_profit: realized_profit,
      balance_after: balance_after,
      has_fee: fee_amount.positive?,
      computable: true
    )
  end
end
