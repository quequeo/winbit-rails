require 'rails_helper'

RSpec.describe DepositOption, type: :model do
  describe 'validations' do
    it 'is valid with valid CASH_ARS attributes' do
      option = DepositOption.new(category: 'CASH_ARS', label: 'Efectivo Pesos', currency: 'ARS', details: {})
      expect(option).to be_valid
    end

    it 'is valid with valid BANK_ARS attributes' do
      option = DepositOption.new(
        category: 'BANK_ARS',
        label: 'Banco Galicia',
        currency: 'ARS',
        details: { 'bank_name' => 'Galicia', 'holder' => 'Winbit SRL', 'cbu_cvu' => '0070000000000000001' }
      )
      expect(option).to be_valid
    end

    it 'is valid with valid CRYPTO attributes' do
      option = DepositOption.new(
        category: 'CRYPTO',
        label: 'USDT TRC20',
        currency: 'USDT',
        details: { 'address' => 'TF7j33woKnMVFALtvRVdnFWnneNrUCVvAr', 'network' => 'TRC20' }
      )
      expect(option).to be_valid
    end

    it 'is valid with valid LEMON attributes' do
      option = DepositOption.new(
        category: 'LEMON',
        label: 'Lemon Cash',
        currency: 'ARS',
        details: { 'lemon_tag' => '$winbit' }
      )
      expect(option).to be_valid
    end

    it 'is valid with valid SWIFT attributes' do
      option = DepositOption.new(
        category: 'SWIFT',
        label: 'Mercury Bank',
        currency: 'USD',
        details: { 'bank_name' => 'Mercury', 'holder' => 'Winbit LLC', 'swift_code' => 'MERYUS33', 'account_number' => '123456789' }
      )
      expect(option).to be_valid
    end

    it 'requires category' do
      option = DepositOption.new(label: 'Test', currency: 'ARS', details: {})
      expect(option).not_to be_valid
      expect(option.errors[:category]).to be_present
    end

    it 'requires label' do
      option = DepositOption.new(category: 'CASH_ARS', currency: 'ARS', details: {})
      expect(option).not_to be_valid
      expect(option.errors[:label]).to be_present
    end

    it 'requires currency' do
      option = DepositOption.new(category: 'CASH_ARS', label: 'Test', details: {})
      expect(option).not_to be_valid
      expect(option.errors[:currency]).to be_present
    end

    it 'rejects invalid category' do
      option = DepositOption.new(category: 'INVALID', label: 'Test', currency: 'ARS', details: {})
      expect(option).not_to be_valid
    end

    it 'rejects invalid currency' do
      option = DepositOption.new(category: 'CASH_ARS', label: 'Test', currency: 'BTC', details: {})
      expect(option).not_to be_valid
    end

    it 'requires bank_name, holder, cbu_cvu for BANK_ARS' do
      option = DepositOption.new(category: 'BANK_ARS', label: 'Banco', currency: 'ARS', details: {})
      expect(option).not_to be_valid
      expect(option.errors[:details].join).to include('bank_name')
      expect(option.errors[:details].join).to include('holder')
      expect(option.errors[:details].join).to include('cbu_cvu')
    end

    it 'requires lemon_tag for LEMON' do
      option = DepositOption.new(category: 'LEMON', label: 'Lemon', currency: 'ARS', details: {})
      expect(option).not_to be_valid
      expect(option.errors[:details].join).to include('lemon_tag')
    end

    it 'requires address and network for CRYPTO' do
      option = DepositOption.new(category: 'CRYPTO', label: 'Crypto', currency: 'USDT', details: {})
      expect(option).not_to be_valid
      expect(option.errors[:details].join).to include('address')
      expect(option.errors[:details].join).to include('network')
    end

    it 'requires bank_name, holder, swift_code, account_number for SWIFT' do
      option = DepositOption.new(category: 'SWIFT', label: 'Bank', currency: 'USD', details: {})
      expect(option).not_to be_valid
      expect(option.errors[:details].join).to include('bank_name')
      expect(option.errors[:details].join).to include('swift_code')
      expect(option.errors[:details].join).to include('account_number')
    end

    it 'defaults active to true' do
      option = DepositOption.create!(category: 'CASH_ARS', label: 'Efectivo', currency: 'ARS', details: {})
      expect(option.active).to be true
    end

    it 'defaults position to 0' do
      option = DepositOption.create!(category: 'CASH_ARS', label: 'Efectivo', currency: 'ARS', details: {})
      expect(option.position).to eq(0)
    end
  end

  describe 'scopes' do
    before do
      DepositOption.create!(category: 'CASH_ARS', label: 'Efectivo', currency: 'ARS', active: true, position: 2)
      DepositOption.create!(category: 'CRYPTO', label: 'USDT TRC20', currency: 'USDT', active: false, position: 1,
                            details: { 'address' => 'TF7j', 'network' => 'TRC20' })
    end

    it '.active returns only active options' do
      expect(DepositOption.active.count).to eq(1)
      expect(DepositOption.active.first.category).to eq('CASH_ARS')
    end

    it '.ordered returns by position, category, label' do
      all = DepositOption.ordered
      expect(all.first.position).to be <= all.last.position
    end
  end
end
