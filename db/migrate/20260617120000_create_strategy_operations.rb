class CreateStrategyOperations < ActiveRecord::Migration[8.0]
  def change
    create_table :strategy_operations, id: :string do |t|
      t.date :operation_date, null: false
      t.string :asset, null: false
      t.string :timeframe
      t.string :direction
      t.string :result_label
      t.decimal :result_usd, precision: 12, scale: 2
      t.decimal :ratio, precision: 8, scale: 4
      t.string :opened_at
      t.string :closed_at
      t.text :notes
      t.string :source, null: false, default: 'manual'
      t.string :created_by_id, null: false

      t.timestamps
    end

    add_index :strategy_operations, :operation_date
    add_index :strategy_operations, [:operation_date, :asset]
    add_foreign_key :strategy_operations, :users, column: :created_by_id
  end
end
