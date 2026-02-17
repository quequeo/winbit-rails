class ExpandTradingFeeFrequencyCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL.squish
      ALTER TABLE investors
      DROP CONSTRAINT IF EXISTS investors_trading_fee_frequency_check
    SQL

    execute <<-SQL.squish
      ALTER TABLE investors
      ADD CONSTRAINT investors_trading_fee_frequency_check
      CHECK (trading_fee_frequency IN ('MONTHLY', 'QUARTERLY', 'SEMESTRAL', 'ANNUAL'))
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE investors
      DROP CONSTRAINT IF EXISTS investors_trading_fee_frequency_check
    SQL

    execute <<-SQL.squish
      ALTER TABLE investors
      ADD CONSTRAINT investors_trading_fee_frequency_check
      CHECK (trading_fee_frequency IN ('QUARTERLY', 'ANNUAL'))
    SQL
  end
end
