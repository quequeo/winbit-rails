# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailCampaigns::Attachment do
  def uploaded(path, content_type:)
    Rack::Test::UploadedFile.new(path, content_type)
  end

  it 'accepts PDF under 10MB' do
    file = Tempfile.new(['ok', '.pdf'])
    file.write('%PDF-1.4')
    file.rewind

    payload = described_class.from_upload(
      uploaded(file.path, content_type: 'application/pdf')
    )

    expect(payload.filename).to eq(File.basename(file.path))
    expect(payload.content_type).to eq('application/pdf')
    expect(payload.content).to include('%PDF')
  ensure
    file.close!
  end

  it 'rejects disallowed extensions' do
    file = Tempfile.new(['bad', '.csv'])
    file.write('a,b')
    file.rewind

    expect {
      described_class.from_upload(
        uploaded(file.path, content_type: 'text/csv')
      )
    }.to raise_error(ArgumentError, /PDF o XLSX/)
  ensure
    file.close!
  end

  it 'rejects files over 10MB' do
    file = Tempfile.new(['big', '.xlsx'])
    file.write('x' * (10.megabytes + 1))
    file.rewind

    expect {
      described_class.from_upload(
        uploaded(
          file.path,
          content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
      )
    }.to raise_error(ArgumentError, /10MB/)
  ensure
    file.close!
  end
end
