require 'rails_helper'

RSpec.describe 'SPA Controller', type: :request do
  describe 'GET /' do
    it 'responds successfully' do
      get '/'

      # Should either serve the SPA (200) or return "UI not built" (404)
      expect([200, 404]).to include(response.status)

      if response.status == 404
        expect(response.body).to include('UI not built')
      else
        expect(response.content_type).to include('text/html')
      end
    end

    it 'catches non-existent routes and serves SPA or 404' do
      get '/some-spa-route'

      expect([200, 404]).to include(response.status)
    end
  end
end
