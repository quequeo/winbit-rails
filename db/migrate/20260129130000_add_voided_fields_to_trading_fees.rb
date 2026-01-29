class AddVoidedFieldsToTradingFees < ActiveRecord::Migration[8.0]
  def change
    add_column :trading_fees, :voided_at, :datetime
    add_reference :trading_fees, :voided_by, type: :string, foreign_key: { to_table: :users }

    add_index :trading_fees, :voided_at
  end
end
