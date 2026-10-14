# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutgoingEmails::SendSchedule do
  def at(day, hour, min = 0)
    described_class::ZONE.local(2026, 10, day, hour, min)
  end

  def schedule(requested, approved)
    described_class.call(requested_at: requested, approved_at: approved)
  end

  # 2026-10-14 is a Wednesday, 2026-10-16 a Friday, 2026-10-17 a Saturday.
  it 'sends at 18:00 when requested before 16:00 and approved between 16:00 and 18:00' do
    expect(schedule(at(14, 14, 19), at(14, 17))).to eq(at(14, 18))
  end

  it 'sends at 18:00 when requested and approved before 16:00' do
    expect(schedule(at(14, 10), at(14, 11))).to eq(at(14, 18))
  end

  it 'sends next morning at 8:00 when requested before 16:00 but approved after 18:00' do
    expect(schedule(at(14, 14), at(14, 19))).to eq(at(15, 8))
  end

  it 'sends next morning at 8:00 when requested after 16:00, whatever the approval time' do
    expect(schedule(at(14, 16, 30), at(14, 17))).to eq(at(15, 8))
    expect(schedule(at(14, 20), at(14, 21))).to eq(at(15, 8))
  end

  it 'sends at 18:00 when an older request is approved before 18:00 on a later day' do
    expect(schedule(at(13, 17), at(14, 10))).to eq(at(14, 18))
  end

  it 'moves Friday evening requests and weekend approvals to Monday 8:00' do
    expect(schedule(at(16, 17), at(16, 17, 30))).to eq(at(19, 8))
    expect(schedule(at(16, 15), at(17, 11))).to eq(at(19, 8))
    expect(schedule(at(16, 10), at(16, 19))).to eq(at(19, 8))
  end

  it 'treats a missing request time as the approval time' do
    expect(schedule(nil, at(14, 10))).to eq(at(14, 18))
  end
end
