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

    it 'also substitutes single-brace variables, leaving other braces as written' do
      result = described_class.render_plain('Hola {nombre}, {otra cosa} {foo}', { 'nombre' => 'Ana' })
      expect(result).to eq('Hola Ana, {otra cosa} {foo}')
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

    it 'renders **bold**, *italic* and a [Botón: ...] to the investor app' do
      result = described_class.render_html(
        "Rentabilidad de **{rentabilidad_mes}%**
[Botón: Ver mi cuenta en la app →]
*El equipo de Winbit*",
        { 'rentabilidad_mes' => '2,14' }
      )
      expect(result).to include('Rentabilidad de <strong>2,14%</strong>')
      expect(result).to include(%(href="#{described_class.app_url}"))
      expect(result).to include('>Ver mi cuenta en la app →</a>')
      expect(result).to include('<em>El equipo de Winbit</em>')
      expect(result).not_to include('[Botón')
    end

    it "links [texto](url) and Winbit's WhatsApp number" do
      result = described_class.render_html('Escribinos por [WhatsApp](https://wa.me/5491141783126) al **+54 9 11 4178-3126**', {})

      expect(result).to include(%(<a href="https://wa.me/5491141783126" style="#{described_class::LINK_STYLE}">WhatsApp</a>))
      expect(result).to include('<strong><a href="https://wa.me/5491141783126"')
      expect(result).to include('>+54 9 11 4178-3126</a></strong>')
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
    expect(vars['primer_nombre']).to eq('Ana')
    expect(vars['mes_nombre']).to eq('abril 2026')
    expect(vars['mes_titulo']).to eq('Abril 2026')
    expect(vars['rentabilidad_mes']).to eq('2,50')
    expect(vars['capital']).to eq('6.484,00')
    expect(vars['acumulado_anual']).not_to be_nil
  end
end
