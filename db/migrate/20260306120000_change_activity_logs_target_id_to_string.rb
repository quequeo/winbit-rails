# frozen_string_literal: true

class ChangeActivityLogsTargetIdToString < ActiveRecord::Migration[8.0]
  def up
    change_column :activity_logs, :target_id, :string, using: 'target_id::text'
  end

  def down
    change_column :activity_logs, :target_id, :bigint, using: 'target_id::bigint'
  end
end
