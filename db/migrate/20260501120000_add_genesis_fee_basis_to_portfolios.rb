# frozen_string_literal: true

class AddGenesisFeeBasisToPortfolios < ActiveRecord::Migration[8.0]
  def change
    add_column :portfolios, :genesis_vpcust_usd, :decimal, precision: 15, scale: 2
    add_column :portfolios, :genesis_fee_basis_at, :datetime
  end
end
