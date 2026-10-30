# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::ChartSvg do
  it 'returns an empty string when there are no rows' do
    expect(described_class.build(rows: [], initial_value: 1000, initial_label: 'Sep-26')).to eq('')
  end

  it 'renders an svg with one point per row plus the initial value, labeled with initial_label' do
    rows = [
      { label: 'Jan-26', portfolio_value: 1100 },
      { label: 'Feb-26', portfolio_value: 1250 },
    ]

    svg = described_class.build(rows: rows, initial_value: 1000, initial_label: 'Dec-25')

    expect(svg).to include('<svg')
    expect(svg.scan('<circle').size).to eq(3)
    expect(svg).to include('Dec-25')
    expect(svg).to include('Feb-26')
    expect(svg).to include('USD 1.250')
  end
  it 'keeps the USD axis values in a left gutter so the line never runs over them' do
    rows = [{ label: 'Jan-26', portfolio_value: 123_456 }]

    svg = described_class.build(rows: rows, initial_value: 118_000, initial_label: 'Dec-25')

    label_xs = svg.scan(/<text x="([\d.]+)" [^>]*font-size="14"[^>]*>USD /).flatten.map(&:to_f)
    first_point_x = svg[/<circle cx="([\d.]+)"/, 1].to_f
    expect(label_xs.size).to eq(3)
    expect(label_xs).to all(be < first_point_x)
  end
end
