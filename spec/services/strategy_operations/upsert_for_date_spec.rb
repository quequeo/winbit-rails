require 'rails_helper'

RSpec.describe StrategyOperations::UpsertForDate do
  let!(:admin) do
    User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '1')
  end

  it 'creates strategy operation for a date' do
    upsert = described_class.new(
      date: Date.new(2026, 5, 4),
      created_by: admin,
      result_usd: 850,
      params: {
        asset: 'MNQ',
        direction: 'SHORT',
        result_label: 'POSITIVO',
        opened_at: '12:08',
        closed_at: '12:10',
      },
    )

    expect(upsert.call).to be(true)
    operation = StrategyOperation.find_by!(operation_date: Date.new(2026, 5, 4))
    expect(operation.asset).to eq('MNQ')
    expect(operation.result_usd).to eq(850.0)
    expect(operation.opened_at).to eq('12:08')
  end

  it 'rejects invalid time format' do
    upsert = described_class.new(
      date: Date.new(2026, 5, 4),
      created_by: admin,
      result_usd: 100,
      params: {
        asset: 'MES',
        result_label: 'NEGATIVO',
        opened_at: '12,08',
        closed_at: '12:10',
      },
    )

    expect(upsert.call).to be(false)
    expect(upsert.error).to include('HH:MM')
  end

  it 'replaces existing operations for the same date' do
    StrategyOperation.create!(
      operation_date: Date.new(2026, 5, 4),
      asset: 'MES',
      created_by: admin,
      source: 'import',
    )

    described_class.new(
      date: Date.new(2026, 5, 4),
      created_by: admin,
      result_usd: 200,
      params: {
        asset: 'MNQ',
        result_label: 'NEGATIVO',
        opened_at: '10:00',
        closed_at: '10:30',
      },
    ).call

    expect(StrategyOperation.where(operation_date: Date.new(2026, 5, 4)).count).to eq(1)
    expect(StrategyOperation.find_by!(operation_date: Date.new(2026, 5, 4)).asset).to eq('MNQ')
  end

  it 'clears operations when asset is blank' do
    StrategyOperation.create!(
      operation_date: Date.new(2026, 5, 4),
      asset: 'MES',
      created_by: admin,
      source: 'import',
    )

    described_class.new(date: Date.new(2026, 5, 4), created_by: admin, params: { asset: '' }).call

    expect(StrategyOperation.where(operation_date: Date.new(2026, 5, 4)).count).to eq(0)
  end
end
