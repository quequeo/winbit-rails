class CreateRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :requests, id: :string do |t|
      t.string :investor_id, null: false

      t.string :request_type, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :method, null: false
      t.string :status, null: false, default: 'PENDING'

      t.string :lemontag
      t.string :transaction_hash
      t.string :network
      t.text :notes

      t.datetime :requested_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :processed_at
    end

    add_index :requests, [:investor_id, :status]
    add_index :requests, [:status, :requested_at]
    add_foreign_key :requests, :investors

    add_check_constraint :requests,
      "request_type IN ('DEPOSIT', 'WITHDRAWAL')",
      name: 'requests_type_check'
    add_check_constraint :requests,
      "method IN ('USDT', 'USDC', 'LEMON_CASH', 'CASH', 'SWIFT')",
      name: 'requests_method_check'
    add_check_constraint :requests,
      "status IN ('PENDING', 'APPROVED', 'REJECTED')",
      name: 'requests_status_check'

    add_check_constraint :requests,
      "network IS NULL OR network IN ('TRC20', 'BEP20', 'ERC20', 'POLYGON')",
      name: 'requests_network_check'
  end
end
