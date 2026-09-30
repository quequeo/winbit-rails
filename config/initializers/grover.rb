# frozen_string_literal: true

# Grover (Chrome headless via Puppeteer) config for the monthly investor
# report PDF (app/services/investor_monthly_report_pdfs/generate.rb).
#
# - `--no-sandbox`/`--disable-setuid-sandbox` are required for Chrome to launch
#   inside Heroku's container (no user namespaces) - without them Puppeteer's
#   launch fails outright, sandbox or not.
# - `executable_path`: only set if PUPPETEER_EXECUTABLE_PATH is present, so
#   Puppeteer's own downloaded Chromium is used by default (both locally, once
#   `npm i puppeteer` has run, and on Heroku via `bin/post_compile`).
#   PUPPETEER_CACHE_DIR (Heroku config var, currently /app/puppeteer_browsers)
#   points the install step and the runtime launch at the same path.
#
#   Getting the install step to actually run at the right time took three
#   tries (confirmed via real build+deploy each time, not just locally):
#   the Node buildpack's own build phase (heroku-postbuild, where this used
#   to live) is NOT safe for this - nothing written to the build directory
#   during that phase survives, regardless of name or nesting (tried a
#   dotdir directly under /app, then nested under node_modules/, then a
#   plain non-dot/non-"cache"-named top-level dir; all three vanished from
#   the deployed slug despite the build log showing the download succeed).
#   Something in the Node buildpack's post-postbuild bookkeeping (cache
#   save/pruning) resets the build dir against its own known paths.
#   `bin/post_compile` runs later - after the Ruby buildpack's own bundle
#   install, once the Node buildpack (and whatever it does internally) has
#   fully finished - which is why the install lives there now instead.
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
