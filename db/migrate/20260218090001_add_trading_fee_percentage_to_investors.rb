class AddTradingFeePercentageToInvestors < ActiveRecord::Migration[8.0]
  def change
    add_column :investors, :trading_fee_percentage, :decimal, precision: 5, scale: 2, null: false, default: 30
    add_check_constraint :investors,
                         'trading_fee_percentage > 0 AND trading_fee_percentage <= 100',
                         name: 'investors_trading_fee_percentage_check'
  end
end
