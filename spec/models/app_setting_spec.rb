require 'rails_helper'

RSpec.describe AppSetting, type: :model do
  describe 'validations' do
    it 'requires a key' do
      setting = AppSetting.new(value: 'test')
      expect(setting).not_to be_valid
      expect(setting.errors[:key]).to include("can't be blank")
    end

    it 'requires unique key' do
      AppSetting.create!(key: 'test_key', value: 'test')
      duplicate = AppSetting.new(key: 'test_key', value: 'test2')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include('has already been taken')
    end
  end

  describe '.get' do
    it 'returns nil for non-existent key' do
      expect(AppSetting.get('non_existent')).to be_nil
    end

    it 'returns string value as-is' do
      AppSetting.create!(key: 'test', value: 'hello')
      expect(AppSetting.get('test')).to eq('hello')
    end

    it 'parses JSON arrays' do
      AppSetting.create!(key: 'test', value: '["a","b","c"]')
      expect(AppSetting.get('test')).to eq(['a', 'b', 'c'])
    end

    it 'parses JSON objects' do
      AppSetting.create!(key: 'test', value: '{"foo":"bar"}')
      expect(AppSetting.get('test')).to eq({ 'foo' => 'bar' })
    end
  end

  describe '.set' do
    it 'creates a new setting' do
      expect {
        AppSetting.set('new_key', 'value')
      }.to change(AppSetting, :count).by(1)

      expect(AppSetting.get('new_key')).to eq('value')
    end

    it 'updates an existing setting' do
      AppSetting.create!(key: 'existing', value: 'old')

      expect {
        AppSetting.set('existing', 'new')
      }.not_to change(AppSetting, :count)

      expect(AppSetting.get('existing')).to eq('new')
    end

    it 'converts arrays to JSON' do
      AppSetting.set('test', ['a', 'b'])
      setting = AppSetting.find_by(key: 'test')
      expect(setting.value).to eq('["a","b"]')
    end

    it 'converts hashes to JSON' do
      AppSetting.set('test', { foo: 'bar' })
      setting = AppSetting.find_by(key: 'test')
      expect(setting.value).to eq('{"foo":"bar"}')
    end

    it 'sets description if provided' do
      AppSetting.set('test', 'value', description: 'Test description')
      setting = AppSetting.find_by(key: 'test')
      expect(setting.description).to eq('Test description')
    end
  end

  describe '.investor_notifications_enabled?' do
    it 'returns false when not set' do
      expect(AppSetting.investor_notifications_enabled?).to be false
    end

    it 'returns true when set to "true"' do
      AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'true')
      expect(AppSetting.investor_notifications_enabled?).to be true
    end

    it 'returns false when set to "false"' do
      AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
      expect(AppSetting.investor_notifications_enabled?).to be false
    end
  end

  describe '.investor_email_whitelist' do
    it 'returns empty array when not set' do
      expect(AppSetting.investor_email_whitelist).to eq([])
    end

    it 'returns array of emails when set' do
      emails = ['test1@example.com', 'test2@example.com']
      AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, emails)
      expect(AppSetting.investor_email_whitelist).to eq(emails)
    end
  end
end
