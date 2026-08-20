class CreateInvestorMonthlyReportPdfs < ActiveRecord::Migration[8.0]
  def change
    create_table :investor_monthly_report_pdfs, id: :string do |t|
      t.string :investor_id, null: false
      t.string :month, null: false
      t.string :original_filename, null: false
      t.string :content_type, null: false, default: "application/pdf"
      t.integer :byte_size, null: false, default: 0
      t.binary :pdf_data, null: false
      t.string :uploaded_by_id

      t.timestamps
    end

    add_index :investor_monthly_report_pdfs, [ :investor_id, :month ],
              unique: true, name: "index_investor_monthly_report_pdfs_on_investor_and_month"
    add_index :investor_monthly_report_pdfs, :month
    add_foreign_key :investor_monthly_report_pdfs, :investors
    add_foreign_key :investor_monthly_report_pdfs, :users, column: :uploaded_by_id
    add_check_constraint :investor_monthly_report_pdfs,
                         "month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'",
                         name: "investor_monthly_report_pdfs_month_format"
  end
end
