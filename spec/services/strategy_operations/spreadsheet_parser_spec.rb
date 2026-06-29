require 'rails_helper'

RSpec.describe StrategyOperations::SpreadsheetParser do
  let(:path) { Rails.root.join('data/backtesting_2026_mayo_junio.xlsx').to_s }

  it 'parses backtesting rows without semana column' do
    skip 'fixture spreadsheet missing' unless File.exist?(path)

    rows = described_class.new(path: path).rows
    expect(rows.length).to eq(38)
    expect(rows.map(&:operation_date).uniq).to include(Date.new(2026, 5, 4), Date.new(2026, 6, 24))
    expect(rows.first.asset).to eq('MYM')
    expect(rows.first.opened_at).to eq('12:08')
    expect(rows.first.closed_at).to eq('12:10')
  end
end
