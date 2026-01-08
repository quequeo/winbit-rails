class SpaController < ActionController::Base
  def index
    path = Rails.public_path.join('index.html')
    unless File.exist?(path)
      render plain: 'UI not built', status: :not_found
      return
    end

    render file: path, layout: false, content_type: 'text/html'
  end
end
