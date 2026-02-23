class DropPlanConfigs < ActiveRecord::Migration[8.0]
  def up
    drop_table :plan_configs
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
