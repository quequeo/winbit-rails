require 'rails_helper'

RSpec.describe 'Admin operation day captures', type: :request do
  let!(:admin) do
    User.create!(email: 'cap-req@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: 'cap-req')
  end

  before { login_as(admin, scope: :user) }
  after { logout(:user) }

  def create_capture!(date:, filename:)
    OperationDayCapture.create!(
      capture_date: date,
      asset: 'MNQ',
      result_label: 'POSITIVO',
      original_filename: filename,
      content_type: 'image/png',
      byte_size: 4,
      image_data: 'PNG!',
      created_by: admin,
    )
  end

  describe 'GET /api/admin/v1/operation_day_captures' do
    it 'returns counts by date' do
      create_capture!(date: Date.new(2026, 5, 4), filename: 'NQ_04.05.26_POSITIVO.png')
      create_capture!(date: Date.new(2026, 5, 4), filename: 'BTC_04.05.26_NEGATIVO.png')

      get '/api/admin/v1/operation_day_captures'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']).to include(hash_including('date' => '2026-05-04', 'count' => 2))
    end

    it 'lists captures for a date' do
      create_capture!(date: Date.new(2026, 5, 4), filename: 'NQ_04.05.26_POSITIVO.png')

      get '/api/admin/v1/operation_day_captures', params: { date: '2026-05-04' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json['data'].first['originalFilename']).to eq('NQ_04.05.26_POSITIVO.png')
      expect(json['data'].first['imageUrl']).to include('/operation_day_captures/')
    end
  end

  describe 'GET /api/admin/v1/operation_day_captures/:id/image' do
    it 'serves the binary image' do
      capture = create_capture!(date: Date.new(2026, 5, 4), filename: 'NQ_04.05.26_POSITIVO.png')

      get "/api/admin/v1/operation_day_captures/#{capture.id}/image"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('image/png')
      expect(response.body).to eq('PNG!')
    end
  end

  describe 'POST /api/admin/v1/operation_day_captures' do
    it 'attaches a file when a strategy operation exists that day' do
      StrategyOperation.create!(
        operation_date: Date.new(2026, 5, 4),
        asset: 'MNQ',
        result_label: 'POSITIVO',
        created_by: admin,
        source: 'manual',
      )
      file = Tempfile.new(['NQ_04.05.26_POSITIVO', '.png'])
      file.binmode
      file.write("\x89PNG")
      file.rewind

      post '/api/admin/v1/operation_day_captures',
           params: { file: Rack::Test::UploadedFile.new(file.path, 'image/png', true, original_filename: 'NQ_04.05.26_POSITIVO.png') }

      expect(response).to have_http_status(:created)
      expect(OperationDayCapture.count).to eq(1)
    ensure
      file.close!
    end
  end
end
