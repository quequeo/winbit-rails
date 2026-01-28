module Middleware
  # Ensures HTML responses are not cached by browsers/CDNs.
  #
  # This is important because our React admin UI is served from `public/index.html`
  # and Rails' `public_file_server.headers` uses far-future caching for all static
  # files in production (good for assets, bad for HTML).
  class NoCacheHtml
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      content_type = headers["Content-Type"] || headers["content-type"]
      if content_type&.include?("text/html")
        headers["Cache-Control"] = "no-store"
      end

      [status, headers, body]
    end
  end
end

