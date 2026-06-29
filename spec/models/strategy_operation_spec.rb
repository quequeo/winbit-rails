require 'rails_helper'

RSpec.describe StrategyOperation, type: :model do
  let!(:admin) do
    User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '1')
  end

  it 'is valid with required attributes' do
    operation = described_class.new(
      operation_date: Date.new(2026, 5, 4),
      asset: 'MNQ',
      result_label: 'POSITIVO',
      opened_at: '12:08',
      closed_at: '12:10',
      created_by: admin,
      source: 'manual',
    )

    expect(operation).to be_valid
  end

  it 'requires asset and operation_date' do
    operation = described_class.new(created_by: admin, source: 'manual')
    expect(operation).not_to be_valid
    expect(operation.errors[:asset]).to be_present
    expect(operation.errors[:operation_date]).to be_present
  end
end
