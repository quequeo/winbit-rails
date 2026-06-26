require 'rails_helper'

RSpec.describe StrategyOperations::Importer do
  let!(:admin) do
    User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '1')
  end
  let(:path) { Rails.root.join('data/backtesting_2026_mayo_junio.xlsx').to_s }

  before do
    DailyOperatingResult.create!(
      date: Date.new(2026, 5, 4),
      percent: -0.5,
      applied_by: admin,
      applied_at: Time.current,
    )
    DailyOperatingResult.create!(
      date: Date.new(2026, 5, 22),
      percent: -0.29,
      applied_by: admin,
      applied_at: Time.current,
    )
    DailyOperatingResult.create!(
      date: Date.new(2026, 6, 24),
      percent: 0.5,
      applied_by: admin,
      applied_at: Time.current,
    )
  end

  it 'imports one row per admin date and skips dates without admin operativa' do
    skip 'fixture spreadsheet missing' unless File.exist?(path)

    importer = described_class.new(path: path, created_by: admin, replace_existing: true)
    expect(importer.call).to be(true)
    expect(importer.imported_count).to eq(3)
    expect(StrategyOperation.count).to eq(3)
    expect(StrategyOperation.find_by(operation_date: Date.new(2026, 5, 1))).to be_nil
    expect(StrategyOperation.find_by(operation_date: Date.new(2026, 5, 29))).to be_nil
  end

  it 'keeps the row with the largest absolute USD on multi-operation days' do
    skip 'fixture spreadsheet missing' unless File.exist?(path)

    described_class.new(path: path, created_by: admin, replace_existing: true).call
    operation = StrategyOperation.find_by!(operation_date: Date.new(2026, 5, 22))
    expect(operation.asset).to eq('NQ')
    expect(operation.result_usd).to eq(-712.0)
  end
end
