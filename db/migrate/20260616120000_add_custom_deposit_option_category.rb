class AddCustomDepositOptionCategory < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :deposit_options, name: "deposit_options_category_check"
    add_check_constraint :deposit_options,
      "category IN ('CASH_ARS', 'CASH_USD', 'BANK_ARS', 'LEMON', 'CRYPTO', 'SWIFT', 'CUSTOM')",
      name: "deposit_options_category_check"
  end

  def down
    remove_check_constraint :deposit_options, name: "deposit_options_category_check"
    add_check_constraint :deposit_options,
      "category IN ('CASH_ARS', 'CASH_USD', 'BANK_ARS', 'LEMON', 'CRYPTO', 'SWIFT')",
      name: "deposit_options_category_check"
  end
end
