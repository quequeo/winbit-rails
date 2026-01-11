class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :notify_deposit_created, :boolean, default: true, null: false
    add_column :users, :notify_withdrawal_created, :boolean, default: true, null: false
  end
end
