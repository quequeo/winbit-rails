class AddWalletAddressToRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :requests, :wallet_address, :string
  end
end
