class CreateDepositOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :deposit_options, id: :string do |t|
      t.string  :category,  null: false
      t.string  :label,     null: false
      t.string  :currency,  null: false
      t.jsonb   :details,   null: false, default: {}
      t.boolean :active,    null: false, default: true
      t.integer :position,  null: false, default: 0

      t.timestamps
    end

    add_index :deposit_options, [:active, :position]
    add_index :deposit_options, :category

    add_check_constraint :deposit_options,
      "category IN ('CASH_ARS', 'CASH_USD', 'BANK_ARS', 'LEMON', 'CRYPTO', 'SWIFT')",
      name: "deposit_options_category_check"

    add_check_constraint :deposit_options,
      "currency IN ('ARS', 'USD', 'USDT', 'USDC')",
      name: "deposit_options_currency_check"
  end
end
