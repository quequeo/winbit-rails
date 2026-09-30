# frozen_string_literal: true

# Grover (Chrome headless via Puppeteer) config for the monthly investor
# report PDF (app/services/investor_monthly_report_pdfs/generate.rb).
#
# - `--no-sandbox`/`--disable-setuid-sandbox` are required for Chrome to launch
#   inside Heroku's container (no user namespaces) - without them Puppeteer's
#   launch fails outright, sandbox or not.
# - `executable_path`: only set if PUPPETEER_EXECUTABLE_PATH is present, so
#   Puppeteer's own bundled Chromium is used by default (both locally, once
#   `npm i puppeteer` has run, and on Heroku via the Chrome buildpack).
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
