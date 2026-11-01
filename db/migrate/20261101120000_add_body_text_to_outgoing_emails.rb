class AddBodyTextToOutgoingEmails < ActiveRecord::Migration[8.0]
  def change
    add_column :outgoing_emails, :body_text, :text
  end
end
