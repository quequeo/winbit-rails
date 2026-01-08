# frozen_string_literal: true

class AddDeviseToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      # NOTE: users.email already exists from CreateUsers.

      # Database authenticatable
      t.string :encrypted_password, null: false, default: ''

      # Recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      # Rememberable
      t.datetime :remember_created_at

      # OmniAuth
      t.string :provider
      t.string :uid
    end

    add_index :users, :reset_password_token, unique: true
    add_index :users, [:provider, :uid], unique: true
  end
end
