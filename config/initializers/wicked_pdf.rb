# frozen_string_literal: true

# wkhtmltopdf binary location for the monthly investor report PDF
# (app/services/investor_monthly_report_pdfs/generate.rb).
#
# - On Heroku: the wkhtmltopdf-heroku gem (see Gemfile) ships the binary and
#   points wicked_pdf at it via its own railtie, before this file runs - no
#   buildpack needed. IMPORTANT: merge into WickedPdf.config here, don't
#   reassign it (`WickedPdf.config = {...}`), or this overwrites that
#   auto-configured exe_path with nil.
# - Locally: set WKHTMLTOPDF_BINARY to override, or put wkhtmltopdf on PATH
#   and wicked_pdf finds it automatically.
WickedPdf.config ||= {}
WickedPdf.config.merge!(
  { exe_path: ENV['WKHTMLTOPDF_BINARY'].presence }.compact
)
