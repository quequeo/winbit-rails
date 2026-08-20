# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::NameMatcher do
  let!(:tulio) { Investor.create!(email: 'tulio@test.com', name: 'Tulio Capparelli', status: 'ACTIVE') }
  let!(:eugenio) { Investor.create!(email: 'eugenio@test.com', name: 'Eugenio Carrió', status: 'ACTIVE') }

  it 'matches ignoring case and accents' do
    matcher = described_class.new
    expect(matcher.find('TULIO CAPPARELLI').investor).to eq(tulio)
    expect(matcher.find('EUGENIO CARRIO').investor).to eq(eugenio)
  end

  it 'returns investor_not_found when nobody matches' do
    matcher = described_class.new
    expect(matcher.find('NO EXISTE').reason).to eq('investor_not_found')
    expect(matcher.find('NO EXISTE').investor).to be_nil
  end

  it 'returns ambiguous_name when two investors normalize to the same name' do
    Investor.create!(email: 'tulio2@test.com', name: 'TULIO CAPPARELLI', status: 'ACTIVE')
    matcher = described_class.new
    result = matcher.find('Tulio Capparelli')
    expect(result.reason).to eq('ambiguous_name')
    expect(result.investor).to be_nil
  end
end
