# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::ChartSvg do
  it 'returns an empty string when there are no rows' do
    expect(described_class.build(rows: [], initial_value: 1000)).to eq('')
  end

  it 'renders an svg with one point per row plus the initial value' do
    rows = [
      { label: 'Jan-26', portfolio_value: 1100 },
      { label: 'Feb-26', portfolio_value: 1250 },
    ]

    svg = described_class.build(rows: rows, initial_value: 1000)

    expect(svg).to include('<svg')
    expect(svg.scan('<circle').size).to eq(3)
    expect(svg).to include('Feb-26')
    expect(svg).to include('USD 1.250')
  end
end
