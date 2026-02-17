class SeedDepositOptionsFromWallets < ActiveRecord::Migration[8.0]
  def up
    wallets = execute("SELECT asset, network, address, enabled FROM wallets ORDER BY asset, network")
    position = 1

    wallets.each do |wallet|
      id = SecureRandom.uuid
      label = "#{wallet['asset']} (#{wallet['network']})"
      currency = wallet['asset']
      active = wallet['enabled'] == true || wallet['enabled'] == 't'
      details = { address: wallet['address'], network: wallet['network'] }.to_json

      execute <<-SQL.squish
        INSERT INTO deposit_options (id, category, label, currency, details, active, position, created_at, updated_at)
        VALUES ('#{id}', 'CRYPTO', '#{label}', '#{currency}', '#{details}', #{active}, #{position}, NOW(), NOW())
      SQL
      position += 1
    end
  end

  def down
    execute("DELETE FROM deposit_options WHERE category = 'CRYPTO'")
  end
end
