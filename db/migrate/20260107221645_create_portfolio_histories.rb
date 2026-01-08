class CreatePortfolioHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :portfolio_histories, id: :string do |t|
      t.string :investor_id, null: false
      t.datetime :date, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.string :event, null: false

      t.decimal :amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :previous_balance, precision: 15, scale: 2, null: false, default: 0
      t.decimal :new_balance, precision: 15, scale: 2, null: false, default: 0

      t.string :status, null: false, default: 'COMPLETED'
      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    add_index :portfolio_histories, [:investor_id, :date]
    add_foreign_key :portfolio_histories, :investors

    add_check_constraint :portfolio_histories,
      "status IN ('PENDING', 'COMPLETED', 'REJECTED')",
      name: 'portfolio_histories_status_check'
  end
end
