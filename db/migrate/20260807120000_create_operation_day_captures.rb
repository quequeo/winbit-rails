class CreateOperationDayCaptures < ActiveRecord::Migration[8.0]
  def change
    create_table :operation_day_captures, id: :string do |t|
      t.date :capture_date, null: false
      t.string :asset
      t.string :result_label
      t.string :original_filename, null: false
      t.string :content_type, null: false, default: "image/png"
      t.integer :byte_size, null: false, default: 0
      t.binary :image_data, null: false
      t.string :created_by_id

      t.timestamps
    end

    add_index :operation_day_captures, :capture_date
    add_index :operation_day_captures, :original_filename, unique: true
    add_foreign_key :operation_day_captures, :users, column: :created_by_id
  end
end
