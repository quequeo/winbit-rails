# frozen_string_literal: true

# Grover (Chrome headless via Puppeteer) config for the monthly investor
# report PDF (app/services/investor_monthly_report_pdfs/generate.rb).
#
# - `--no-sandbox`/`--disable-setuid-sandbox` are required for Chrome to launch
#   inside Heroku's container (no user namespaces) - without them Puppeteer's
#   launch fails outright, sandbox or not.
# - `--disable-dev-shm-usage`: Heroku dynos give /dev/shm very little space,
#   which crashes/OOMs Chrome under the default shared-memory usage - this
#   makes it fall back to disk instead. Standard fix for Chrome-on-Heroku.
# - `executable_path`: only set if PUPPETEER_EXECUTABLE_PATH is present, so
#   Puppeteer's own downloaded Chromium is used by default. PUPPETEER_CACHE_DIR
#   (Heroku config var, currently /app/puppeteer_browsers) points both the
#   install and the launch at the same path.
#
#   The install itself happens at RUNTIME, on first use (see
#   InvestorMonthlyReportPdfs::EnsureChromeInstalled), not during the Heroku
#   build. Every build-time approach tried (heroku-postbuild, then
#   bin/post_compile) showed the download succeeding in the build log, but
#   the result never made it into the deployed slug either way - confirmed
#   with real deploys, not just locally - and on this Heroku-24 stack
#   bin/post_compile turned out not to even run at all. Installing at
#   runtime instead sidesteps whatever that was: /app is writable at
#   runtime (unlike during the build), so the download just needs to
#   survive for this dyno's lifetime, not make it into a slug.
Grover.configure do |config|
  config.options = {
    format: 'A4',
    landscape: true,
    print_background: true,
    prefer_css_page_size: true,
    margin: { top: '0', bottom: '0', left: '0', right: '0' },
    launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    executable_path: ENV['PUPPETEER_EXECUTABLE_PATH'].presence,
  }.compact
end
