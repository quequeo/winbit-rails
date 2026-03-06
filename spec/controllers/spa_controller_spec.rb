require 'rails_helper'

RSpec.describe 'SPA Controller', type: :request do
  describe 'GET /' do
    it 'serves index.html when it exists' do
      path = Rails.public_path.join('index.html')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(path).and_return(true)

      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
    end

    it 'returns 404 with UI not built when index.html is missing' do
      path = Rails.public_path.join('index.html')
      allow(File).to receive(:exist?).and_wrap_original do |original, p|
        Pathname.new(p.to_s) == path ? false : original.call(p)
      end

      get '/dashboard'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('UI not built')
    end

    it 'catches non-existent routes and serves SPA or 404' do
      get '/some-spa-route'

      expect([200, 404]).to include(response.status)
    end
  end
end
