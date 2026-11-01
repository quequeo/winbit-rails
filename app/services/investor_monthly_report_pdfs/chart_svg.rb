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
    PAD_RIGHT = 10
    PAD_TOP = 26
    PAD_BOTTOM = 22
    GRID_FRACTIONS = [0, 0.5, 1].freeze
    AXIS_FONT_SIZE = 14
    # Generous per-character width for the axis font, so the left gutter
    # always fits the widest "USD 123.456" value and the line starts after it.
    AXIS_CHAR_WIDTH = 8.4
    AXIS_GAP = 12

    def self.build(rows:, initial_value:, initial_label:)
      new(rows:, initial_value:, initial_label:).build
    end

    def initialize(rows:, initial_value:, initial_label:)
      @rows = rows
      @initial_value = initial_value.to_f
      @initial_label = initial_label
    end

    def build
      return '' if @rows.empty?

      values = [@initial_value] + @rows.map { |r| r[:portfolio_value].to_f }
      labels = [@initial_label] + @rows.map { |r| r[:label] }
      vmin = values.min
      vmax = values.max
      vrange = (vmax - vmin).zero? ? 1.0 : (vmax - vmin)
      n = values.size
      axis_values = GRID_FRACTIONS.map { |frac| [frac, "USD #{money(vmin + (vrange * frac))}"] }
      @plot_left = (axis_values.map { |_, text| text.length }.max * AXIS_CHAR_WIDTH).ceil + AXIS_GAP

      points = values.each_with_index.map { |v, i| [x_at(i, n), y_at(v, vmin, vrange)] }
      path = "M #{points.map { |x, y| "#{x.round(1)},#{y.round(1)}" }.join(' L ')}"
      area_path = "#{path} L #{points.last[0].round(1)},#{HEIGHT - PAD_BOTTOM} L #{points.first[0].round(1)},#{HEIGHT - PAD_BOTTOM} Z"

      <<~SVG
        <svg viewBox="0 0 #{WIDTH} #{HEIGHT}" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
          #{gridlines(axis_values, end_text: "USD #{money(values.last)}")}
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
      @plot_left + (WIDTH - @plot_left - PAD_RIGHT) * index.to_f / (count - 1)
    end

    def y_at(value, vmin, vrange)
      grid_y((value - vmin) / vrange)
    end

    def grid_y(frac)
      PAD_TOP + (HEIGHT - PAD_TOP - PAD_BOTTOM) * (1 - frac)
    end

    def dots(points)
      points.each_with_index.map do |(x, y), i|
        last = i == points.size - 1
        fill = last ? '#ECE4D5' : '#0D0F0E'
        radius = last ? 7 : 4
        %(<circle cx="#{x.round(1)}" cy="#{y.round(1)}" r="#{radius}" fill="#{fill}" stroke="#479785" stroke-width="#{last ? 2.2 : 1.8}" />)
      end.join
    end

    # USD values live in a left gutter, right-aligned against the plot and
    # vertically centered on their gridline, so the line never crosses them.
    # A value already shown as the end point's label isn't repeated on the axis.
    def gridlines(axis_values, end_text:)
      axis_values.map do |frac, text|
        y = grid_y(frac)
        line = %(<line x1="#{@plot_left}" y1="#{y.round(1)}" x2="#{WIDTH - PAD_RIGHT}" y2="#{y.round(1)}" stroke="#28312D" stroke-width="1"/>)
        next line if text == end_text

        <<~LINE
          #{line}
          <text x="#{@plot_left - AXIS_GAP}" y="#{(y + 5).round(1)}" font-size="#{AXIS_FONT_SIZE}" fill="#A7AAA2" text-anchor="end">#{text}</text>
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
      formatted = whole.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1.').reverse
      value.negative? ? "-#{formatted}" : formatted
    end
  end
end
