# frozen_string_literal: true

# Grover (Chrome headless via Puppeteer) config for the monthly investor
# report PDF (app/services/investor_monthly_report_pdfs/generate.rb).
#
# - `--no-sandbox`/`--disable-setuid-sandbox` are required for Chrome to launch
#   inside Heroku's container (no user namespaces) - without them Puppeteer's
#   launch fails outright, sandbox or not.
# - `executable_path`: only set if PUPPETEER_EXECUTABLE_PATH is present, so
#   Puppeteer's own downloaded Chromium is used by default (both locally, once
#   `npm i puppeteer` has run, and on Heroku via the explicit
#   `npx puppeteer browsers install chrome` in the root package.json's
#   heroku-postbuild). PUPPETEER_CACHE_DIR (Heroku config var) points the
#   install step and the runtime launch at the same path - it must live
#   under node_modules/ (confirmed: a top-level dotdir like
#   /app/.puppeteer-cache does NOT survive Heroku's slug finalization, even
#   though the build log shows the download succeeding there; node_modules/
#   is the one directory the Node buildpack guarantees ships in the slug).
#   The jontewks/puppeteer buildpack only supplies the system shared
#   libraries Chrome needs to launch - not Chrome itself.
Grover.configure do |config|
  config.options = {
    format: 'A4',
    landscape: true,
    print_background: true,
    prefer_css_page_size: true,
    margin: { top: '0', bottom: '0', left: '0', right: '0' },
    launch_args: ['--no-sandbox', '--disable-setuid-sandbox'],
    executable_path: ENV['PUPPETEER_EXECUTABLE_PATH'].presence,
  }.compact
end
