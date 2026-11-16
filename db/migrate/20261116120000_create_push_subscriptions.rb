# frozen_string_literal: true

# Celulares (navegadores) del inversor que aceptaron recibir avisos con la app
# cerrada (Web Push).
class CreatePushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :push_subscriptions, id: :string do |t|
      t.string :investor_id, null: false
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :user_agent
      t.datetime :last_sent_at

      t.timestamps
    end

    add_index :push_subscriptions, :endpoint, unique: true
    add_index :push_subscriptions, :investor_id
    add_foreign_key :push_subscriptions, :investors
  end
end
