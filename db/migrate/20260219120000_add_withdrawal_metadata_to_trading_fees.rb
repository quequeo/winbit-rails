class AddWithdrawalMetadataToTradingFees < ActiveRecord::Migration[8.0]
  def change
    add_column :trading_fees, :source, :string, null: false, default: 'PERIODIC'
    add_column :trading_fees, :withdrawal_amount, :decimal, precision: 15, scale: 2
    add_column :trading_fees, :withdrawal_request_id, :string

    add_foreign_key :trading_fees, :requests, column: :withdrawal_request_id
    add_index :trading_fees, :source
    add_index :trading_fees, :withdrawal_request_id

    add_check_constraint :trading_fees,
                         "source IN ('PERIODIC','WITHDRAWAL')",
                         name: 'trading_fees_source_check'
  end
end
