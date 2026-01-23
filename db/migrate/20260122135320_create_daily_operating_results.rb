class CreateDailyOperatingResults < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_operating_results, id: :string do |t|
      t.date :date, null: false
      t.decimal :percent, precision: 6, scale: 2, null: false
      t.string :applied_by_id, null: false
      t.datetime :applied_at, null: false
      t.text :notes

      t.timestamps

      t.index :date, unique: true
      t.index :applied_at
    end

    add_foreign_key :daily_operating_results, :users, column: :applied_by_id
  end
end
