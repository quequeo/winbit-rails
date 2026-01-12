class CreateActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_logs do |t|
      t.string :user_id, null: false
      t.references :target, polymorphic: true, null: false
      t.string :action, null: false, limit: 30
      t.jsonb :metadata, default: {}

      t.timestamp :created_at, null: false
    end

    add_index :activity_logs, [:user_id, :created_at]
    add_index :activity_logs, [:target_type, :target_id]
    add_index :activity_logs, :created_at
    add_foreign_key :activity_logs, :users
  end
end
