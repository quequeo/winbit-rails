# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_10_031444) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "investors", id: :string, force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "status", default: "ACTIVE", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_investors_on_email", unique: true
    t.check_constraint "status::text = ANY (ARRAY['ACTIVE'::character varying::text, 'INACTIVE'::character varying::text])", name: "investors_status_check"
  end

  create_table "portfolio_histories", id: :string, force: :cascade do |t|
    t.string "investor_id", null: false
    t.datetime "date", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "event", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "previous_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "new_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.string "status", default: "COMPLETED", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["investor_id", "date"], name: "index_portfolio_histories_on_investor_id_and_date"
    t.check_constraint "status::text = ANY (ARRAY['PENDING'::character varying::text, 'COMPLETED'::character varying::text, 'REJECTED'::character varying::text])", name: "portfolio_histories_status_check"
  end

  create_table "portfolios", id: :string, force: :cascade do |t|
    t.string "investor_id", null: false
    t.decimal "current_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "total_invested", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "accumulated_return_usd", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "accumulated_return_percent", precision: 10, scale: 4, default: "0.0", null: false
    t.decimal "annual_return_usd", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "annual_return_percent", precision: 10, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["investor_id"], name: "index_portfolios_on_investor_id", unique: true
  end

  create_table "requests", id: :string, force: :cascade do |t|
    t.string "investor_id", null: false
    t.string "request_type", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "method", null: false
    t.string "status", default: "PENDING", null: false
    t.string "lemontag"
    t.string "transaction_hash"
    t.string "network"
    t.text "notes"
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "processed_at"
    t.string "attachment_url"
    t.index ["investor_id", "status"], name: "index_requests_on_investor_id_and_status"
    t.index ["status", "requested_at"], name: "index_requests_on_status_and_requested_at"
    t.check_constraint "method::text = ANY (ARRAY['USDT'::character varying::text, 'USDC'::character varying::text, 'LEMON_CASH'::character varying::text, 'CASH'::character varying::text, 'SWIFT'::character varying::text])", name: "requests_method_check"
    t.check_constraint "network IS NULL OR (network::text = ANY (ARRAY['TRC20'::character varying::text, 'BEP20'::character varying::text, 'ERC20'::character varying::text, 'POLYGON'::character varying::text]))", name: "requests_network_check"
    t.check_constraint "request_type::text = ANY (ARRAY['DEPOSIT'::character varying::text, 'WITHDRAWAL'::character varying::text])", name: "requests_type_check"
    t.check_constraint "status::text = ANY (ARRAY['PENDING'::character varying::text, 'APPROVED'::character varying::text, 'REJECTED'::character varying::text])", name: "requests_status_check"
  end

  create_table "users", id: :string, force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.string "role", default: "ADMIN", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "provider"
    t.string "uid"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "role::text = ANY (ARRAY['ADMIN'::character varying::text, 'SUPERADMIN'::character varying::text])", name: "users_role_check"
  end

  create_table "wallets", id: :string, force: :cascade do |t|
    t.string "asset", null: false
    t.string "network", null: false
    t.string "address", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset", "network"], name: "index_wallets_on_asset_and_network", unique: true
    t.check_constraint "asset::text = ANY (ARRAY['USDT'::character varying::text, 'USDC'::character varying::text])", name: "wallets_asset_check"
    t.check_constraint "network::text = ANY (ARRAY['TRC20'::character varying::text, 'BEP20'::character varying::text, 'ERC20'::character varying::text, 'POLYGON'::character varying::text])", name: "wallets_network_check"
  end

  add_foreign_key "portfolio_histories", "investors"
  add_foreign_key "portfolios", "investors"
  add_foreign_key "requests", "investors"
end
