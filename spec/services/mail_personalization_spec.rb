# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailPersonalization do
  def at(day, hour)
    described_class::ZONE.local(2026, 10, day, hour)
  end

  describe '.greeting' do
    it 'greets by the Argentina time of sending' do
      expect(described_class.greeting(at(15, 8))).to eq('Buenos días')
      expect(described_class.greeting(at(15, 18))).to eq('Buenas tardes')
      expect(described_class.greeting(at(15, 21))).to eq('Buenas noches')
    end
  end

  describe '.requested_when' do
    it 'refers to today, yesterday or the weekday and date' do
      expect(described_class.requested_when(at(15, 14), at(15, 18))).to eq('el día de hoy')
      expect(described_class.requested_when(at(14, 17), at(15, 8))).to eq('el día de ayer')
      expect(described_class.requested_when(at(16, 17), at(19, 8))).to eq('el viernes 16/10')
    end

    it 'falls back when the request time is unknown' do
      expect(described_class.requested_when(nil, at(15, 8))).to eq('recientemente')
    end
  end

  describe '.apply' do
    it 'replaces the draft tokens' do
      html = "<p>#{described_class::GREETING_TOKEN}, Luis</p><p>solicitado #{described_class::REQUESTED_TOKEN}.</p>"

      expect(described_class.apply(html, requested_at: at(14, 17), at: at(15, 8)))
        .to eq('<p>Buenos días, Luis</p><p>solicitado el día de ayer.</p>')
    end
  end

  describe '.first_name' do
    it 'takes the first name and fixes all-caps names' do
      expect(described_class.first_name('Luis Matías Crocci')).to eq('Luis')
      expect(described_class.first_name('CECILIA SARLI')).to eq('Cecilia')
    end
  end
end
