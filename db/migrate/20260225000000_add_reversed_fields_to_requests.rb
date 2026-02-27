# frozen_string_literal: true

class AddReversedFieldsToRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :requests, :reversed_at, :datetime
    add_reference :requests, :reversed_by, type: :string, foreign_key: { to_table: :users }

    remove_check_constraint :requests, name: 'requests_status_check'
    add_check_constraint :requests,
      "status::text = ANY (ARRAY['PENDING'::character varying::text, 'APPROVED'::character varying::text, 'REJECTED'::character varying::text, 'REVERSED'::character varying::text])",
      name: 'requests_status_check'
  end
end
