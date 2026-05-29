# frozen_string_literal: true

class CreateInvestorMonthlyAnnexRows < ActiveRecord::Migration[8.0]
  def change
    create_table :investor_monthly_annex_rows do |t|
      t.string :investor_id, null: false
      t.date :month, null: false
      t.decimal :return_percent, precision: 10, scale: 4
      t.decimal :return_usd, precision: 15, scale: 2
      t.decimal :deposits, precision: 15, scale: 2, default: 0, null: false
      t.decimal :withdrawals, precision: 15, scale: 2, default: 0, null: false
      t.decimal :service_cost, precision: 15, scale: 2, default: 0, null: false
      t.decimal :portfolio_value, precision: 15, scale: 2
      t.boolean :opening_snapshot, default: false, null: false
      t.string :source, null: false, default: 'spreadsheet'
      t.timestamps
    end

    add_index :investor_monthly_annex_rows, [:investor_id, :month], unique: true
    add_foreign_key :investor_monthly_annex_rows, :investors
  end
end
