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
#   heroku-postbuild). PUPPETEER_CACHE_DIR (Heroku config var, currently
#   /app/puppeteer_browsers) points the install step and the runtime launch
#   at the same path. Two things that look safe are NOT here: a dotdir
#   directly under /app (confirmed via a real build+deploy: the download
#   succeeds during heroku-postbuild, but it's gone from the slug afterward)
#   and anything nested under node_modules/ (Heroku's "Pruning
#   devDependencies" step re-runs `npm ci`, which wipes and rebuilds
#   node_modules from package-lock.json, taking any manually-placed files
#   with it - confirmed via `heroku run`). A plain, non-dot, non-"cache"-named
#   top-level directory is what survives both. The jontewks/puppeteer
#   buildpack only supplies the system shared libraries Chrome needs to
#   launch - not Chrome itself.
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
