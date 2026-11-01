# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OutgoingEmails scheduling' do
  let(:admin) { User.create!(email: 'sched-admin@test.com', name: 'Admin', role: 'ADMIN') }
  let(:investor) { Investor.create!(email: 'sched@test.com', name: 'Sched Inv', status: 'ACTIVE') }
  let(:email) do
    OutgoingEmail.create!(investor: investor, kind: 'INVESTOR_WELCOME', to_email: investor.email, subject: 'Hola',
                          body_html: '<p>Hola</p>', scheduled_for: scheduled_for)
  end
  let(:scheduled_for) { 2.hours.from_now }

  before { ActionMailer::Base.deliveries.clear }

  describe OutgoingEmails::Schedule do
    it 'keeps the suggested time when it is still in the future' do
      described_class.call(outgoing_email: email, scheduled_by: admin)

      expect(email.reload).to have_attributes(status: 'SCHEDULED', scheduled_by: admin)
      expect(email.scheduled_for).to be_within(1.second).of(scheduled_for)
    end

    context 'when the suggested time already passed' do
      let(:scheduled_for) { 1.hour.ago }

      it 'recalculates a future send time' do
        described_class.call(outgoing_email: email, scheduled_by: admin)

        expect(email.reload.scheduled_for).to be > Time.current
      end
    end

    it 'refuses to schedule sent emails' do
      email.update!(status: 'SENT')
      expect { described_class.call(outgoing_email: email) }.to raise_error(StandardError, /ya está programado/)
      expect { described_class.call(outgoing_email: email, at: 1.day.from_now) }.to raise_error(StandardError, /enviado/)
    end

    it 'does not schedule twice with the default time' do
      described_class.call(outgoing_email: email)
      expect { described_class.call(outgoing_email: email) }.to raise_error(StandardError, /ya está programado/)
    end

    it 'schedules at a chosen date and time, also when it was already scheduled' do
      described_class.call(outgoing_email: email)
      described_class.call(outgoing_email: email, scheduled_by: admin, at: '2099-11-02T10:30:00-03:00')

      expect(email.reload).to have_attributes(status: 'SCHEDULED', scheduled_by: admin)
      expect(email.scheduled_for).to eq(Time.zone.parse('2099-11-02T13:30:00Z'))
    end

    it 'rejects past or invalid times' do
      expect { described_class.call(outgoing_email: email, at: 1.hour.ago.iso8601) }
        .to raise_error(OutgoingEmails::Schedule::InvalidTime, /futura/)
      expect { described_class.call(outgoing_email: email, at: 'mañana') }
        .to raise_error(OutgoingEmails::Schedule::InvalidTime, /válida/)
      expect(email.reload.status).to eq('DRAFT')
    end
  end

  describe OutgoingEmails::SendDue do
    it 'sends scheduled emails whose time has come and leaves the rest' do
      due = OutgoingEmail.create!(investor: investor, kind: 'INVESTOR_WELCOME', to_email: investor.email, subject: 'Due',
                                  body_html: '<p>x</p>', status: 'SCHEDULED', scheduled_for: 1.minute.ago, scheduled_by: admin)
      later = OutgoingEmail.create!(investor: investor, kind: 'INVESTOR_WELCOME', to_email: investor.email, subject: 'Later',
                                    body_html: '<p>x</p>', status: 'SCHEDULED', scheduled_for: 1.hour.from_now)
      draft = email

      expect(described_class.call).to eq(1)

      expect(due.reload.status).to eq('SENT')
      expect(later.reload.status).to eq('SCHEDULED')
      expect(draft.reload.status).to eq('DRAFT')
      expect(ActionMailer::Base.deliveries.map(&:subject)).to eq([ 'Due' ])
    end

    it 'marks failures and keeps going' do
      OutgoingEmail.create!(investor: investor, kind: 'INVESTOR_WELCOME', to_email: investor.email, subject: 'Boom',
                            body_html: '<p>x</p>', status: 'SCHEDULED', scheduled_for: 1.minute.ago)
      allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now).and_raise(Net::ReadTimeout)

      expect(described_class.call).to eq(0)
      expect(OutgoingEmail.find_by(subject: 'Boom').status).to eq('FAILED')
    end
  end
end
