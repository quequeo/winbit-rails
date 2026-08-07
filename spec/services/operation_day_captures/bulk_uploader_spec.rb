require 'rails_helper'

RSpec.describe OperationDayCaptures::BulkUploader do
  let!(:admin) do
    User.create!(email: 'bulk-cap@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'bulk-cap')
  end

  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmpdir) }

  def write_png(name)
    path = File.join(tmpdir, name)
    File.binwrite(path, "\x89PNG\r\n\x1a\nfake")
    path
  end

  it 'uploads when a StrategyOperation exists for that day and is idempotent' do
    StrategyOperation.create!(
      operation_date: Date.new(2026, 5, 4),
      asset: 'MNQ',
      result_label: 'BE+',
      created_by: admin,
      source: 'manual',
    )
    path = write_png('NQ_04.05.26_BE.png')

    uploader = described_class.new(paths: [path], created_by: admin)
    uploader.call
    expect(uploader.summary[:uploaded_count]).to eq(1)
    expect(OperationDayCapture.last.result_label).to eq('BE+')

    again = described_class.new(paths: [path], created_by: admin)
    again.call
    expect(again.summary[:skip_breakdown]['already_attached']).to eq(1)
    expect(OperationDayCapture.count).to eq(1)
  end

  it 'leaves result_label blank when filename BE has no usable admin label' do
    StrategyOperation.create!(
      operation_date: Date.new(2026, 5, 19),
      asset: 'MYM',
      result_label: nil,
      created_by: admin,
      source: 'import',
    )
    path = write_png('MYM_19.05.26_BE.png')

    uploader = described_class.new(paths: [path], created_by: admin)
    uploader.call

    expect(uploader.summary[:uploaded_count]).to eq(1)
    expect(OperationDayCapture.last.result_label).to be_nil
  end

  it 'skips days without StrategyOperation and SIMULADA files' do
    write_png('NQ_01.04.26_POSITIVO.png')
    write_png('MES_26.05.26_POSITIVASIMULADA.png')
    StrategyOperation.create!(
      operation_date: Date.new(2026, 5, 26),
      asset: 'MES',
      result_label: 'POSITIVO',
      created_by: admin,
      source: 'manual',
    )

    uploader = described_class.new(paths: [tmpdir], created_by: admin)
    uploader.call
    summary = uploader.summary

    expect(summary[:uploaded_count]).to eq(0)
    expect(summary[:skip_breakdown]['no_operation']).to eq(1)
    expect(summary[:skip_breakdown]['simulada']).to eq(1)
  end
end
