require 'rails_helper'

RSpec.describe NotificationGate do
  before do
    # Reset settings before each test
    AppSetting.where(key: [
      AppSetting::INVESTOR_NOTIFICATIONS_ENABLED,
      AppSetting::INVESTOR_EMAIL_WHITELIST
    ]).destroy_all
  end

  describe '.should_send_to_investor?' do
    context 'when email is blank' do
      it 'returns false' do
        expect(NotificationGate.should_send_to_investor?(nil)).to be false
        expect(NotificationGate.should_send_to_investor?('')).to be false
      end
    end

    context 'when notifications are globally enabled' do
      before do
        AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'true')
      end

      it 'returns true for any email' do
        expect(NotificationGate.should_send_to_investor?('anyone@example.com')).to be true
      end
    end

    context 'when notifications are globally disabled' do
      before do
        AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
      end

      it 'returns false for emails not in whitelist' do
        expect(NotificationGate.should_send_to_investor?('anyone@example.com')).to be false
      end

      it 'returns true for emails in whitelist' do
        AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['test@example.com'])
        expect(NotificationGate.should_send_to_investor?('test@example.com')).to be true
      end

      it 'handles case-insensitive email matching' do
        AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['test@example.com'])
        expect(NotificationGate.should_send_to_investor?('TEST@EXAMPLE.COM')).to be true
      end

      it 'handles whitespace in email' do
        AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['test@example.com'])
        expect(NotificationGate.should_send_to_investor?('  test@example.com  ')).to be true
      end
    end

    context 'when notifications setting does not exist' do
      it 'checks whitelist' do
        AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['test@example.com'])
        expect(NotificationGate.should_send_to_investor?('test@example.com')).to be true
        expect(NotificationGate.should_send_to_investor?('other@example.com')).to be false
      end
    end
  end

  describe '.in_whitelist?' do
    before do
      AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, [
        'test1@example.com',
        'test2@example.com'
      ])
    end

    it 'returns true for emails in whitelist' do
      expect(NotificationGate.in_whitelist?('test1@example.com')).to be true
      expect(NotificationGate.in_whitelist?('test2@example.com')).to be true
    end

    it 'returns false for emails not in whitelist' do
      expect(NotificationGate.in_whitelist?('other@example.com')).to be false
    end

    it 'returns false for blank emails' do
      expect(NotificationGate.in_whitelist?(nil)).to be false
      expect(NotificationGate.in_whitelist?('')).to be false
    end

    it 'handles case-insensitive matching' do
      expect(NotificationGate.in_whitelist?('TEST1@EXAMPLE.COM')).to be true
    end

    it 'handles whitespace' do
      expect(NotificationGate.in_whitelist?('  test1@example.com  ')).to be true
    end
  end

  describe '.should_send_to_admin?' do
    it 'always returns true' do
      expect(NotificationGate.should_send_to_admin?).to be true
    end
  end

  describe '.log_blocked_notification' do
    it 'logs to Rails logger' do
      expect(Rails.logger).to receive(:info).with(/Blocked test_notification notification/)
      NotificationGate.log_blocked_notification('test@example.com', 'test_notification')
    end
  end
end
