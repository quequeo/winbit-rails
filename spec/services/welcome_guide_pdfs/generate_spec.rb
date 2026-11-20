# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WelcomeGuidePdfs::Generate do
  let(:investor) do
    Investor.create!(email: 'guia@test.com', name: 'Ignacio Marano', status: 'ACTIVE', trading_fee_percentage: 25)
  end

  def html_for(greeting)
    data = described_class.new(investor: investor, greeting: greeting).data
    ActionController::Base.renderer.render(template: 'welcome_guide_pdfs/document', layout: false, locals: { data: data })
  end

  it 'fills in the name, the greeting and the investor fee' do
    html = html_for('bienvenido')

    expect(html).to include('Bienvenido</span> a Winbit,<br><span>Ignacio</span>',
                            'comisión del <span class="f">25%</span> solo sobre',
                            'la comisión es de <span class="f">USD 25,00</span>',
                            'app.winbit.com.ar/instalar', '@winbit.capital', 'data:font/ttf;base64,')
    expect(html).not_to match(/\{(nombre|%|Bienvenido\/a)\}/)
  end

  it 'uses Bienvenida when chosen' do
    expect(html_for('bienvenida')).to include('Bienvenida</span> a Winbit')
  end
end
