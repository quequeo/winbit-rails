class RemoveCodeFromInvestors < ActiveRecord::Migration[8.0]
  def change
    remove_index :investors, :code, if_exists: true
    remove_column :investors, :code, :string
  end
end
