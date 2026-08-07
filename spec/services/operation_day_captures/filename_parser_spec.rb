require 'rails_helper'

RSpec.describe OperationDayCaptures::FilenameParser do
  it 'maps NQ and BTC aliases and parses YY dates' do
    parsed = described_class.parse('NQ_04.05.26_POSITIVO.png')
    expect(parsed.ok).to eq(true)
    expect(parsed.asset).to eq('MNQ')
    expect(parsed.capture_date).to eq(Date.new(2026, 5, 4))
    expect(parsed.filename_result).to eq('POSITIVO')

    btc = described_class.parse('BTC_09.07.26_NEGATIVO.png')
    expect(btc.asset).to eq('MBT')
  end

  it 'accepts YYYY outlier dates' do
    parsed = described_class.parse('NQ_02.06.2026_POSITIVO.png')
    expect(parsed.ok).to eq(true)
    expect(parsed.capture_date).to eq(Date.new(2026, 6, 2))
  end

  it 'skips SIMULADA labels' do
    parsed = described_class.parse('MES_26.05.26_POSITIVASIMULADA.png')
    expect(parsed.ok).to eq(false)
    expect(parsed.skip_reason).to eq('simulada')
  end

  it 'rejects unknown assets' do
    parsed = described_class.parse('XYZ_01.05.26_POSITIVO.png')
    expect(parsed.ok).to eq(false)
    expect(parsed.skip_reason).to eq('alias_fail')
  end
end
