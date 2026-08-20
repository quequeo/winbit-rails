# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::FilenameParser do
  it 'parses Reporte julio - NAME.pdf' do
    parsed = described_class.parse('Reporte julio - TULIO CAPPARELLI.pdf')

    expect(parsed.ok).to be(true)
    expect(parsed.investor_name).to eq('TULIO CAPPARELLI')
    expect(parsed.month_number).to eq(7)
    expect(parsed.year).to be_nil
  end

  it 'parses optional year and accented names' do
    parsed = described_class.parse('Reporte Julio 2026 - Eugenio Carrió.pdf')

    expect(parsed.ok).to be(true)
    expect(parsed.investor_name).to eq('Eugenio Carrió')
    expect(parsed.month_number).to eq(7)
    expect(parsed.year).to eq(2026)
  end

  it 'rejects unknown filenames' do
    parsed = described_class.parse('tulio.pdf')
    expect(parsed.ok).to be(false)
    expect(parsed.skip_reason).to eq('unparseable_filename')
  end
end
