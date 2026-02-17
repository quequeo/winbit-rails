require 'rails_helper'

RSpec.describe DailyOperatingResult, type: :model do
  let(:admin) { User.create!(email: 'admin-dor@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'dor-admin') }

  def build_result(attrs = {})
    DailyOperatingResult.new(
      {
        date: Date.new(2026, 1, 20),
        percent: 2.5,
        applied_by: admin,
        applied_at: Time.current,
        notes: 'test'
      }.merge(attrs)
    )
  end

  it 'is valid with valid attributes' do
    expect(build_result).to be_valid
  end

  it 'requires unique date' do
    build_result.save!
    duplicate = build_result(percent: 1.2)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:date]).to include('has already been taken')
  end

  it 'validates percent range' do
    too_low = build_result(percent: -101)
    too_high = build_result(percent: 101)

    expect(too_low).not_to be_valid
    expect(too_high).not_to be_valid
  end

  it 'requires applied_by and applied_at' do
    result = build_result(applied_by: nil, applied_at: nil)
    expect(result).not_to be_valid
    expect(result.errors[:applied_by_id]).to be_present
    expect(result.errors[:applied_at]).to be_present
  end
end
