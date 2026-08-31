# frozen_string_literal: true

require 'base64'

module InvestorMonthlyReportPdfs
  # Static design assets (logo lockups + cover/back photography) for the
  # monthly PDF report, embedded as data: URIs so the rendered HTML has no
  # external file dependencies at PDF-render time.
  #
  # These come from the report template design (see app/assets/images/monthly_report).
  # Swap the files there to update the look; no code change needed.
  module Assets
    DIR = Rails.root.join('app', 'assets', 'images', 'monthly_report')
    FONT_DIR = Rails.root.join('app', 'assets', 'fonts', 'monthly_report')

    FILES = {
      logo_light: ['logo-light.png', 'image/png'],
      logo_dark: ['logo-dark.png', 'image/png'],
      cover: ['cover.jpg', 'image/jpeg'],
      back: ['back.jpg', 'image/jpeg'],
    }.freeze

    # Noto Sans (regular/bold) for body text, Noto Sans Display Extra
    # Condensed SemiBold for headline/number treatments.
    FONT_FILES = {
      sans_regular: 'NotoSans-Regular.ttf',
      sans_bold: 'NotoSans-Bold.ttf',
      display_condensed_semibold: 'NotoSansDisplay_ExtraCondensed-SemiBold.ttf',
    }.freeze

    class << self
      def data_uri(key)
        cache[key]
      end

      def font_data_uri(key)
        font_cache[key]
      end

      private

      def cache
        @cache ||= FILES.to_h { |key, (filename, mime)| [key, build_data_uri(DIR, filename, mime)] }
      end

      def font_cache
        @font_cache ||= FONT_FILES.to_h { |key, filename| [key, build_data_uri(FONT_DIR, filename, 'font/ttf')] }
      end

      def build_data_uri(dir, filename, mime)
        bytes = File.binread(dir.join(filename))
        "data:#{mime};base64,#{Base64.strict_encode64(bytes)}"
      end
    end
  end
end
