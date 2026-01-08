require 'rails_helper'

RSpec.describe Wallet, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      wallet = Wallet.new(asset: 'USDT', network: 'TRC20', address: '0x123...', enabled: true)
      expect(wallet).to be_valid
    end

    it 'requires asset' do
      wallet = Wallet.new(network: 'TRC20', address: '0x123...', enabled: true)
      expect(wallet).not_to be_valid
    end

    it 'requires network' do
      wallet = Wallet.new(asset: 'USDT', address: '0x123...', enabled: true)
      expect(wallet).not_to be_valid
    end

    it 'requires address' do
      wallet = Wallet.new(asset: 'USDT', network: 'TRC20', enabled: true)
      expect(wallet).not_to be_valid
    end

    it 'requires unique combination of asset and network' do
      Wallet.create!(asset: 'USDT', network: 'TRC20', address: '0x123...', enabled: true)
      wallet = Wallet.new(asset: 'USDT', network: 'TRC20', address: '0x456...', enabled: true)
      expect(wallet).not_to be_valid
    end

    it 'defaults enabled to true' do
      wallet = Wallet.create!(asset: 'USDT', network: 'TRC20', address: '0x123...')
      expect(wallet.enabled).to be true
    end

    it 'allows same asset on different networks' do
      Wallet.create!(asset: 'USDT', network: 'TRC20', address: '0x123...', enabled: true)
      wallet = Wallet.new(asset: 'USDT', network: 'ERC20', address: '0x456...', enabled: true)
      expect(wallet).to be_valid
    end
  end

  describe 'scopes' do
    before do
      Wallet.create!(asset: 'USDT', network: 'TRC20', address: '0x1', enabled: true)
      Wallet.create!(asset: 'USDC', network: 'ERC20', address: '0x2', enabled: false)
    end

    it 'can query enabled wallets' do
      enabled_wallets = Wallet.where(enabled: true)
      expect(enabled_wallets.count).to eq(1)
      expect(enabled_wallets.first.asset).to eq('USDT')
    end

    it 'can query disabled wallets' do
      disabled_wallets = Wallet.where(enabled: false)
      expect(disabled_wallets.count).to eq(1)
      expect(disabled_wallets.first.asset).to eq('USDC')
    end
  end
end
