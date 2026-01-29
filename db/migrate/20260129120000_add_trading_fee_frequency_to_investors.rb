class AddTradingFeeFrequencyToInvestors < ActiveRecord::Migration[8.0]
  def change
    add_column :investors, :trading_fee_frequency, :string, null: false, default: "QUARTERLY"

    add_index :investors, :trading_fee_frequency

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE investors
          ADD CONSTRAINT investors_trading_fee_frequency_check
          CHECK (trading_fee_frequency IN ('QUARTERLY', 'ANNUAL'))
        SQL
      end

      dir.down do
        execute <<~SQL
          ALTER TABLE investors
          DROP CONSTRAINT IF EXISTS investors_trading_fee_frequency_check
        SQL
      end
    end
  end
end
