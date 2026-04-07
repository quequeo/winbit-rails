class AddStrategyReturnFieldsToPortfolios < ActiveRecord::Migration[8.0]
  def change
    add_column :portfolios, :strategy_return_all_usd, :decimal, precision: 15, scale: 2
    add_column :portfolios, :strategy_return_all_percent, :decimal, precision: 10, scale: 4
    add_column :portfolios, :strategy_return_ytd_usd, :decimal, precision: 15, scale: 2
    add_column :portfolios, :strategy_return_ytd_percent, :decimal, precision: 10, scale: 4
  end
end
