# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailPersonalization do
  def at(day, hour)
    described_class::ZONE.local(2026, 10, day, hour)
  end

  describe '.greeting' do
    it 'always says Hola' do
      expect(described_class.greeting(at(15, 8))).to eq('Hola')
      expect(described_class.greeting(at(15, 21))).to eq('Hola')
    end
  end

  describe '.requested_when' do
    it 'uses the dd/mm/aaaa date, never today or yesterday' do
      expect(described_class.requested_when(at(15, 14), at(15, 18))).to eq('el 15/10/2026')
      expect(described_class.requested_when(at(14, 17), at(15, 8))).to eq('el 14/10/2026')
    end

    it 'falls back when the request time is unknown' do
      expect(described_class.requested_when(nil)).to eq('recientemente')
    end
  end

  describe '.apply' do
    it 'replaces the tokens of drafts built with the previous format' do
      html = "<p>#{described_class::GREETING_TOKEN}, Luis</p><p>solicitado #{described_class::REQUESTED_TOKEN}.</p>"

      expect(described_class.apply(html, requested_at: at(14, 17)))
        .to eq('<p>Hola, Luis</p><p>solicitado el 14/10/2026.</p>')
    end
  end

  describe '.processing_term' do
    it 'promises the same day before 16:00 on business days and the next business day otherwise' do
      expect(described_class.processing_term(at(15, 10))).to eq('La vamos a procesar hoy antes de las 18:00.')
      expect(described_class.processing_term(at(15, 17))).to include('próximo día hábil')
      expect(described_class.processing_term(at(17, 10))).to include('próximo día hábil')
    end
  end

  describe '.first_name' do
    it 'takes the first name and fixes all-caps names' do
      expect(described_class.first_name('Luis Matías Crocci')).to eq('Luis')
      expect(described_class.first_name('CECILIA SARLI')).to eq('Cecilia')
    end
  end
end
