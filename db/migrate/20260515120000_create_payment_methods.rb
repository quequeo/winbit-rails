class CreatePaymentMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_methods, if_not_exists: true do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :kind, null: false
      t.boolean :active, default: true, null: false
      t.boolean :enabled_for_deposit, default: true, null: false
      t.boolean :enabled_for_withdrawal, default: true, null: false
      t.boolean :requires_network, default: false, null: false
      t.boolean :requires_lemontag, default: false, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :payment_methods, :code, unique: true, if_not_exists: true
    add_index :payment_methods, [:active, :position], if_not_exists: true
  end
end
