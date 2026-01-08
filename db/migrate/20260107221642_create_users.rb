class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :string do |t|
      t.string :email, null: false
      t.string :name
      t.string :role, null: false, default: 'ADMIN'
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_check_constraint :users, "role IN ('ADMIN', 'SUPERADMIN')", name: 'users_role_check'
  end
end
