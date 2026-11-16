# frozen_string_literal: true

class AddCancelledStatusToRequests < ActiveRecord::Migration[8.0]
  STATUSES_BEFORE = %w[PENDING APPROVED REJECTED REVERSED].freeze
  STATUSES_AFTER = (STATUSES_BEFORE + %w[CANCELLED]).freeze

  def up
    add_column :requests, :cancelled_at, :datetime
    replace_status_check(STATUSES_AFTER)
  end

  def down
    execute "UPDATE requests SET status = 'REJECTED' WHERE status = 'CANCELLED'"
    replace_status_check(STATUSES_BEFORE)
    remove_column :requests, :cancelled_at
  end

  private

  def replace_status_check(statuses)
    values = statuses.map { |s| "'#{s}'::character varying::text" }.join(', ')
    remove_check_constraint :requests, name: 'requests_status_check'
    add_check_constraint :requests, "status::text = ANY (ARRAY[#{values}])", name: 'requests_status_check'
  end
end
