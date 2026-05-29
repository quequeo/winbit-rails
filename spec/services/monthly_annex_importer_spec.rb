# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MonthlyAnnexImporter do
  let(:json_path) { Rails.root.join('spec/fixtures/monthly_annex_sample.json') }

  before do
    Investor.create!(email: 'eugenio.carrio7@gmail.com', name: 'Eugenio Carrió', status: 'ACTIVE')
  end

  it 'imports spreadsheet rows for matched investors' do
    importer = described_class.new(json_path: json_path)

    expect(importer.import!).to be(true)
    expect(importer.imported_count).to eq(5)
    expect(importer.errors).to be_empty

    rows = InvestorMonthlyAnnexRow.order(:month)
    expect(rows.map { |r| r.month.strftime('%Y-%m') }).to eq(%w[2025-12 2026-01 2026-02 2026-03 2026-04])
    expect(rows.first.opening_snapshot).to be(true)
    expect(rows.first.portfolio_value.to_f).to eq(6044)
    expect(rows.last.portfolio_value.to_f).to eq(6484)
  end

  it 'imports INGRESO row for Jaime by email mapping' do
    Investor.create!(email: 'jaimegarciamendez@gmail.com', name: 'Jaime García Mendez', status: 'ACTIVE')

    importer = described_class.new(json_path: Rails.root.join('spec/fixtures/monthly_annex_jaime.json'))
    expect(importer.import!).to be(true)

    row = InvestorMonthlyAnnexRow.find_by!(entry_row: true)
    expect(row.portfolio_value.to_f).to eq(500)
    expect(row.month).to eq(Date.new(2026, 4, 1))
  end
end
