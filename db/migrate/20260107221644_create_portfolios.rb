class CreatePortfolios < ActiveRecord::Migration[8.0]
  def change
    create_table :portfolios, id: :string do |t|
      t.string :investor_id, null: false

      t.decimal :current_balance, precision: 15, scale: 2, null: false, default: 0
      t.decimal :total_invested, precision: 15, scale: 2, null: false, default: 0
      t.decimal :accumulated_return_usd, precision: 15, scale: 2, null: false, default: 0
      t.decimal :accumulated_return_percent, precision: 10, scale: 4, null: false, default: 0
      t.decimal :annual_return_usd, precision: 15, scale: 2, null: false, default: 0
      t.decimal :annual_return_percent, precision: 10, scale: 4, null: false, default: 0

      t.timestamps
    end

    add_index :portfolios, :investor_id, unique: true
    add_foreign_key :portfolios, :investors
  end
end
