# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMailer, type: :mailer do
  let(:investor) { Investor.create!(name: 'John Doe', email: 'john@example.com', status: 'ACTIVE') }
  let(:portfolio) { Portfolio.create!(investor: investor, current_balance: 10000, total_invested: 10000) }
  let(:deposit_request) do
    InvestorRequest.create!(
      investor: investor,
      request_type: 'DEPOSIT',
      amount: 1000,
      method: 'USDT',
      network: 'TRC20',
      status: 'PENDING',
      requested_at: Time.current
    )
  end

  before do
    # Reset settings
    AppSetting.where(key: [
      AppSetting::INVESTOR_NOTIFICATIONS_ENABLED,
      AppSetting::INVESTOR_EMAIL_WHITELIST
    ]).destroy_all
  end

  describe 'NotificationGate integration' do
    context 'when notifications are globally disabled' do
      before do
        AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
      end

      it 'does not send email to investor not in whitelist' do
        mail = described_class.deposit_created(investor, deposit_request)
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'sends email to investor in whitelist' do
        AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['john@example.com'])
        mail = described_class.deposit_created(investor, deposit_request)
        expect(mail.message).not_to be_a(ActionMailer::Base::NullMail)
        expect(mail.to).to eq(['john@example.com'])
      end
    end

    context 'when notifications are globally enabled' do
      before do
        AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'true')
      end

      it 'sends email to any investor' do
        mail = described_class.deposit_created(investor, deposit_request)
        expect(mail.message).not_to be_a(ActionMailer::Base::NullMail)
        expect(mail.to).to eq(['john@example.com'])
      end
    end

    describe 'all mailer methods respect NotificationGate' do
      before do
        AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
        portfolio # Ensure portfolio exists
      end

      it 'deposit_created respects gate' do
        mail = described_class.deposit_created(investor, deposit_request)
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'deposit_approved respects gate' do
        mail = described_class.deposit_approved(investor, deposit_request)
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'deposit_rejected respects gate' do
        mail = described_class.deposit_rejected(investor, deposit_request, 'reason')
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'withdrawal_created respects gate' do
        withdrawal = InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          amount: 500,
          method: 'LEMON_CASH',
          lemontag: '$lemonuser',
          status: 'PENDING',
          requested_at: Time.current
        )
        mail = described_class.withdrawal_created(investor, withdrawal)
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'withdrawal_approved respects gate' do
        withdrawal = InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          amount: 500,
          method: 'LEMON_CASH',
          lemontag: '$lemonuser',
          status: 'PENDING',
          requested_at: Time.current
        )
        mail = described_class.withdrawal_approved(investor, withdrawal)
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'withdrawal_rejected respects gate' do
        withdrawal = InvestorRequest.create!(
          investor: investor,
          request_type: 'WITHDRAWAL',
          amount: 500,
          method: 'LEMON_CASH',
          lemontag: '$lemonuser',
          status: 'PENDING',
          requested_at: Time.current
        )
        mail = described_class.withdrawal_rejected(investor, withdrawal, 'reason')
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'campaign_message respects gate without force' do
        mail = described_class.campaign_message(
          investor,
          subject: 'Test',
          body_html: 'Hola',
          force: false
        )
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end

      it 'campaign_message sends with force even when gate blocks' do
        mail = described_class.campaign_message(
          investor,
          subject: 'Campaña',
          body_html: 'Hola',
          force: true
        )
        expect(mail.message).not_to be_a(ActionMailer::Base::NullMail)
        expect(mail.to).to eq(['john@example.com'])
        expect(mail.reply_to).to eq(['winbit.cfds@gmail.com'])
      end

      it 'campaign_message attaches optional file' do
        attachment = EmailCampaigns::Attachment::Payload.new(
          filename: 'informe.pdf',
          content: '%PDF-1.4',
          content_type: 'application/pdf'
        )
        mail = described_class.campaign_message(
          investor,
          subject: 'Campaña',
          body_html: 'Hola',
          force: true,
          attachment: attachment
        )
        expect(mail.attachments.size).to eq(1)
        expect(mail.attachments.first.filename).to eq('informe.pdf')
      end
    end

    describe 'whitelist with different email formats' do
      before do
        AppSetting.set(AppSetting::INVESTOR_NOTIFICATIONS_ENABLED, 'false')
        AppSetting.set(AppSetting::INVESTOR_EMAIL_WHITELIST, ['john@example.com'])
      end

      it 'matches case-insensitively' do
        investor_caps = Investor.create!(name: 'Jane', email: 'JOHN@EXAMPLE.COM', status: 'ACTIVE')
        request = InvestorRequest.create!(
          investor: investor_caps,
          request_type: 'DEPOSIT',
          amount: 1000,
          method: 'USDT',
          network: 'TRC20',
          status: 'PENDING'
        )
        mail = described_class.deposit_created(investor_caps, request)
        expect(mail.message).not_to be_a(ActionMailer::Base::NullMail)
      end
    end
  end
end
