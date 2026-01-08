class CreateInvestors < ActiveRecord::Migration[8.0]
  def change
    create_table :investors, id: :string do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :code, null: false
      t.string :status, null: false, default: 'ACTIVE'
      t.timestamps
    end

    add_index :investors, :email, unique: true
    add_index :investors, :code, unique: true
    add_check_constraint :investors, "status IN ('ACTIVE', 'INACTIVE')", name: 'investors_status_check'
  end
end
