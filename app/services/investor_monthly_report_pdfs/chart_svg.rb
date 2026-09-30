# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Renders the "Evolución del valor del portafolio" line chart (page 3 of
  # the monthly PDF report) as an inline SVG, server-side. No JS charting
  # library is needed: wkhtmltopdf renders plain SVG natively.
  class ChartSvg
    # Flat aspect ratio (matches the CSS .chart box, ~122px tall at full page
    # width) so the report's fixed-height evolution page always has room for
    # the table/acumulado bar below it, up to 12 months of history.
    WIDTH = 1000
    HEIGHT = 120
    PAD_LEFT = 10
    PAD_RIGHT = 10
    PAD_TOP = 26
    PAD_BOTTOM = 22

    def self.build(rows:, initial_value:)
      new(rows:, initial_value:).build
    end

    def initialize(rows:, initial_value:)
      @rows = rows
      @initial_value = initial_value.to_f
    end

    def build
      return '' if @rows.empty?

      values = [@initial_value] + @rows.map { |r| r[:portfolio_value].to_f }
      labels = ['01/26'] + @rows.map { |r| r[:label] }
      vmin = values.min
      vmax = values.max
      vrange = (vmax - vmin).zero? ? 1.0 : (vmax - vmin)
      n = values.size

      points = values.each_with_index.map { |v, i| [x_at(i, n), y_at(v, vmin, vrange)] }
      path = "M #{points.map { |x, y| "#{x.round(1)},#{y.round(1)}" }.join(' L ')}"
      area_path = "#{path} L #{points.last[0].round(1)},#{HEIGHT - PAD_BOTTOM} L #{points.first[0].round(1)},#{HEIGHT - PAD_BOTTOM} Z"

      <<~SVG
        <svg viewBox="0 0 #{WIDTH} #{HEIGHT}" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
          #{gridlines(vmin, vrange)}
          <path d="#{area_path}" fill="#479785" opacity=".07" />
          <path d="#{path}" fill="none" stroke="#479785" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" />
          #{dots(points)}
          #{end_label(points.last, values.last)}
          #{month_labels(points, labels)}
        </svg>
      SVG
    end

    private

    def x_at(index, count)
      PAD_LEFT + (WIDTH - PAD_LEFT - PAD_RIGHT) * index.to_f / (count - 1)
    end

    def y_at(value, vmin, vrange)
      PAD_TOP + (HEIGHT - PAD_TOP - PAD_BOTTOM) * (1 - ((value - vmin) / vrange))
    end

    def dots(points)
      points.each_with_index.map do |(x, y), i|
        last = i == points.size - 1
        fill = last ? '#ECE4D5' : '#0D0F0E'
        radius = last ? 7 : 4
        %(<circle cx="#{x.round(1)}" cy="#{y.round(1)}" r="#{radius}" fill="#{fill}" stroke="#479785" stroke-width="#{last ? 2.2 : 1.8}" />)
      end.join
    end

    def gridlines(vmin, vrange)
      [0, 0.5, 1].map do |frac|
        y = PAD_TOP + (HEIGHT - PAD_TOP - PAD_BOTTOM) * (1 - frac)
        val = vmin + (vrange * frac)
        <<~LINE
          <line x1="#{PAD_LEFT}" y1="#{y.round(1)}" x2="#{WIDTH - PAD_RIGHT}" y2="#{y.round(1)}" stroke="#28312D" stroke-width="1"/>
          <text x="0" y="#{(y - 4).round(1)}" font-size="14" fill="#A7AAA2">USD #{money(val)}</text>
        LINE
      end.join
    end

    def month_labels(points, labels)
      last = points.size - 1
      points.each_with_index.filter_map do |(x, _y), i|
        next unless i.zero? || i == last || i.even?

        # Anchor the first/last labels inward so they don't clip past the
        # viewBox edge - only interior labels can safely center on their point.
        anchor = i.zero? ? 'start' : (i == last ? 'end' : 'middle')
        %(<text x="#{x.round(1)}" y="#{HEIGHT - 6}" font-size="13" fill="#A7AAA2" text-anchor="#{anchor}">#{labels[i]}</text>)
      end.join
    end

    def end_label(point, value)
      x, y = point
      %(<text x="#{(x - 6).round(1)}" y="#{(y - 14).round(1)}" font-size="15" font-weight="700" fill="#479785" text-anchor="end">USD #{money(value)}</text>)
    end

    def money(value)
      whole = value.round.to_i.abs
      formatted = whole.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
      value.negative? ? "-#{formatted}" : formatted
    end
  end
end
