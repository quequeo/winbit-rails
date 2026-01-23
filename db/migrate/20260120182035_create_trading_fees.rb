class CreateTradingFees < ActiveRecord::Migration[8.0]
  def change
    create_table :trading_fees, id: :string do |t|
      t.references :investor, type: :string, null: false, foreign_key: true
      t.references :applied_by, type: :string, null: false, foreign_key: { to_table: :users }
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.decimal :profit_amount, precision: 15, scale: 2, null: false
      t.decimal :fee_percentage, precision: 5, scale: 2, null: false
      t.decimal :fee_amount, precision: 15, scale: 2, null: false
      t.text :notes
      t.datetime :applied_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end

    add_index :trading_fees, [:investor_id, :period_start, :period_end],
              name: 'index_trading_fees_on_investor_and_period'
    add_index :trading_fees, :applied_at
  end
end
