class AddDataSignatureToInvestorMonthlyReportPdfs < ActiveRecord::Migration[8.0]
  def change
    add_column :investor_monthly_report_pdfs, :data_signature, :string
  end
end
