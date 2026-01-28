class RemoveRequestsMethodCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    # Payment methods are now configurable via PaymentMethod records.
    remove_check_constraint :requests, name: "requests_method_check"
  end
end

