# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScheduledMonthlyReportEmail, type: :model do
  def build(attrs = {})
    described_class.new({ month: '2026-10', subject: 'Asunto', body: 'Cuerpo', scheduled_for: 1.day.from_now }.merge(attrs))
  end

  it 'is valid with month, subject, body and time, and starts as SCHEDULED' do
    record = build
    expect(record).to be_valid
    expect(record.status).to eq('SCHEDULED')
  end

  it 'requires a YYYY-MM month, subject, body, time and a known status' do
    expect(build(month: '2026-13')).not_to be_valid
    expect(build(subject: '')).not_to be_valid
    expect(build(body: '')).not_to be_valid
    expect(build(scheduled_for: nil)).not_to be_valid
    expect(build(status: 'OTHER')).not_to be_valid
  end

  it 'is due only while SCHEDULED and once its time arrived' do
    due = build(scheduled_for: 1.minute.ago).tap(&:save!)
    build(scheduled_for: 1.hour.from_now, month: '2026-09').save!
    build(scheduled_for: 1.minute.ago, month: '2026-08', status: 'CANCELED').save!

    expect(described_class.due).to contain_exactly(due)
  end
end
