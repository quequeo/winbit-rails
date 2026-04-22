class AllowZeroTradingFeePercentageForInvestors < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :investors, name: 'investors_trading_fee_percentage_check'
    add_check_constraint :investors,
                         'trading_fee_percentage >= 0 AND trading_fee_percentage <= 100',
                         name: 'investors_trading_fee_percentage_check'
  end

  def down
    remove_check_constraint :investors, name: 'investors_trading_fee_percentage_check'
    add_check_constraint :investors,
                         'trading_fee_percentage > 0 AND trading_fee_percentage <= 100',
                         name: 'investors_trading_fee_percentage_check'
  end
end
