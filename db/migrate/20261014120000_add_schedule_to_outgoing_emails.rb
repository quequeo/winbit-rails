class AddScheduleToOutgoingEmails < ActiveRecord::Migration[8.0]
  def change
    add_column :outgoing_emails, :scheduled_for, :datetime
    add_column :outgoing_emails, :scheduled_by_id, :string
    add_index :outgoing_emails, [ :status, :scheduled_for ]
    add_foreign_key :outgoing_emails, :users, column: :scheduled_by_id
  end
end
