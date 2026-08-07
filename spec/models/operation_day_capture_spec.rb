require 'rails_helper'

RSpec.describe OperationDayCapture, type: :model do
  let!(:admin) do
    User.create!(email: 'capture-admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'cap-1')
  end

  it 'persists a day-level screenshot' do
    capture = described_class.create!(
      capture_date: Date.new(2026, 5, 4),
      asset: 'MNQ',
      result_label: 'POSITIVO',
      original_filename: 'NQ_04.05.26_POSITIVO.png',
      content_type: 'image/png',
      byte_size: 4,
      image_data: 'PNG!',
      created_by: admin,
    )

    expect(capture).to be_persisted
    expect(capture.capture_date).to eq(Date.new(2026, 5, 4))
  end

  it 'requires unique original_filename' do
    described_class.create!(
      capture_date: Date.new(2026, 5, 4),
      original_filename: 'NQ_04.05.26_POSITIVO.png',
      content_type: 'image/png',
      byte_size: 4,
      image_data: 'PNG!',
    )

    dup = described_class.new(
      capture_date: Date.new(2026, 5, 4),
      original_filename: 'NQ_04.05.26_POSITIVO.png',
      content_type: 'image/png',
      byte_size: 4,
      image_data: 'PNG!',
    )

    expect(dup).not_to be_valid
    expect(dup.errors[:original_filename]).to be_present
  end
end
