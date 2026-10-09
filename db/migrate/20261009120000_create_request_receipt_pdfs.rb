class CreateRequestReceiptPdfs < ActiveRecord::Migration[8.0]
  def change
    create_table :request_receipt_pdfs, id: :string do |t|
      t.string :request_id, null: false
      t.string :original_filename, null: false
      t.string :content_type, null: false, default: "application/pdf"
      t.integer :byte_size, null: false, default: 0
      t.binary :pdf_data, null: false

      t.timestamps
    end

    add_index :request_receipt_pdfs, :request_id, unique: true
    add_foreign_key :request_receipt_pdfs, :requests, column: :request_id, on_delete: :cascade
  end
end
