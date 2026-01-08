require 'rails_helper'

RSpec.describe SpaController, type: :controller do
  describe 'GET #index' do
    it 'renders the index.html file' do
      # Create a dummy index.html for testing
      allow(File).to receive(:read).and_return('<html><body>Test</body></html>')

      get :index

      expect(response).to have_http_status(:ok)
    end
  end
end
