class CreateScheduledCampaignEmails < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_campaign_emails, id: :string do |t|
      t.string :month, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.datetime :scheduled_for, null: false
      t.string :status, null: false, default: "SCHEDULED"
      t.jsonb :investor_ids
      t.boolean :app_button, null: false, default: false
      t.string :scheduled_by_id
      t.datetime :sent_at
      t.integer :queued_count
      t.integer :skipped_count
      t.integer :failure_count
      t.text :error

      t.timestamps
    end

    add_index :scheduled_campaign_emails, [ :status, :scheduled_for ]
    add_foreign_key :scheduled_campaign_emails, :users, column: :scheduled_by_id
  end
end
