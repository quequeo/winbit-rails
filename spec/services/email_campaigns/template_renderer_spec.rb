# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailCampaigns::TemplateRenderer do
  describe '.render_plain' do
    it 'substitutes variables' do
      result = described_class.render_plain(
        'Hola {{nombre}}, ganancia {{ganancia_pct}}',
        { 'nombre' => 'Ana', 'ganancia_pct' => '2,50%' }
      )
      expect(result).to eq('Hola Ana, ganancia 2,50%')
    end

    it 'leaves unknown variables intact' do
      expect(described_class.render_plain('X {{foo}}', {})).to eq('X {{foo}}')
    end
  end

  describe '.render_html' do
    it 'escapes HTML in values and converts newlines' do
      result = described_class.render_html(
        "Hola {{nombre}}\n<script>",
        { 'nombre' => '<b>Ana</b>' }
      )
      expect(result).to eq('Hola &lt;b&gt;Ana&lt;/b&gt;<br>&lt;script&gt;')
    end
  end
end

RSpec.describe EmailCampaigns::MonthlyPerformanceVariables do
  let!(:investor) { Investor.create!(email: 'ana@example.com', name: 'Ana Pérez', status: 'ACTIVE') }

  before do
    Portfolio.create!(investor: investor, current_balance: 6484)
    InvestorMonthlyAnnexRow.create!(
      investor: investor,
      month: Date.new(2026, 4, 1),
      return_percent: 2.5,
      return_usd: 158.5,
      portfolio_value: 6484,
      source: 'spreadsheet',
    )
  end

  it 'builds Argentine-formatted variables from MonthlyReportBuilder' do
    vars = described_class.call(investor: investor, report_month: '2026-04')

    expect(vars['nombre']).to eq('Ana Pérez')
    expect(vars['email']).to eq('ana@example.com')
    expect(vars['mes']).to eq('2026-04')
    expect(vars['ganancia_usd']).to eq('$158,50')
    expect(vars['ganancia_pct']).to eq('2,50%')
  end
end
