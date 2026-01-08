class CreateWallets < ActiveRecord::Migration[8.0]
  def change
    create_table :wallets, id: :string do |t|
      t.string :asset, null: false
      t.string :network, null: false
      t.string :address, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :wallets, [:asset, :network], unique: true
    add_check_constraint :wallets, "asset IN ('USDT', 'USDC')", name: 'wallets_asset_check'
    add_check_constraint :wallets,
      "network IN ('TRC20', 'BEP20', 'ERC20', 'POLYGON')",
      name: 'wallets_network_check'
  end
end
