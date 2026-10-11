class CreateOutgoingEmails < ActiveRecord::Migration[8.0]
  def change
    create_table :outgoing_emails, id: :string do |t|
      t.string :investor_id, null: false
      t.string :request_id
      t.string :kind, null: false
      t.string :to_email, null: false
      t.string :subject, null: false
      t.text :body_html, null: false
      t.string :status, null: false, default: "DRAFT"
      t.text :error
      t.datetime :sent_at
      t.string :sent_by_id

      t.timestamps
    end

    add_index :outgoing_emails, :status
    add_index :outgoing_emails, :request_id
    add_index :outgoing_emails, [ :investor_id, :created_at ]
    add_foreign_key :outgoing_emails, :investors
    add_foreign_key :outgoing_emails, :requests, column: :request_id, on_delete: :cascade
    add_foreign_key :outgoing_emails, :users, column: :sent_by_id
  end
end
