# frozen_string_literal: true

# El inversor ve su reporte en la app recién cuando se lo mandamos por mail
# (versión final). Los que ya estaban cargados quedan visibles, como hasta hoy.
class AddPublishedAtToInvestorMonthlyReportPdfs < ActiveRecord::Migration[8.0]
  def up
    add_column :investor_monthly_report_pdfs, :published_at, :datetime
    execute 'UPDATE investor_monthly_report_pdfs SET published_at = updated_at'
  end

  def down
    remove_column :investor_monthly_report_pdfs, :published_at
  end
end
