# frozen_string_literal: true

class AddEntryRowToInvestorMonthlyAnnexRows < ActiveRecord::Migration[8.0]
  def change
    add_column :investor_monthly_annex_rows, :entry_row, :boolean, default: false, null: false
  end
end
