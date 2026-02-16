class AddPasswordDigestToInvestors < ActiveRecord::Migration[8.0]
  def change
    add_column :investors, :password_digest, :string
  end
end
