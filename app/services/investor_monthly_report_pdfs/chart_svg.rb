# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Renders the "Evolución del valor del portafolio" line chart (page 3 of
  # the monthly PDF report) as an inline SVG, server-side. No JS charting
  # library is needed: wkhtmltopdf renders plain SVG natively.
  class ChartSvg
    WIDTH = 1000
    HEIGHT = 260
    PAD_LEFT = 10
    PAD_RIGHT = 10
    PAD_TOP = 34
    PAD_BOTTOM = 30

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

      <<~SVG
        <svg viewBox="0 0 #{WIDTH} #{HEIGHT}" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
          #{gridlines(vmin, vrange)}
          <path d="#{path}" fill="none" stroke="#3f9280" stroke-width="2.5" />
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
        radius = i == points.size - 1 ? 7 : 4
        %(<circle cx="#{x.round(1)}" cy="#{y.round(1)}" r="#{radius}" fill="#3f9280" />)
      end.join
    end

    def gridlines(vmin, vrange)
      [0, 0.5, 1].map do |frac|
        y = PAD_TOP + (HEIGHT - PAD_TOP - PAD_BOTTOM) * (1 - frac)
        val = vmin + (vrange * frac)
        <<~LINE
          <line x1="#{PAD_LEFT}" y1="#{y.round(1)}" x2="#{WIDTH - PAD_RIGHT}" y2="#{y.round(1)}" stroke="rgba(236,228,213,0.12)" stroke-width="1"/>
          <text x="0" y="#{(y - 4).round(1)}" font-size="14" fill="#9c988e">USD #{money(val)}</text>
        LINE
      end.join
    end

    def month_labels(points, labels)
      points.each_with_index.filter_map do |(x, _y), i|
        next unless i.zero? || i == points.size - 1 || i.even?

        %(<text x="#{x.round(1)}" y="#{HEIGHT - 6}" font-size="13" fill="#9c988e" text-anchor="middle">#{labels[i]}</text>)
      end.join
    end

    def end_label(point, value)
      x, y = point
      %(<text x="#{(x - 6).round(1)}" y="#{(y - 14).round(1)}" font-size="15" font-weight="700" fill="#ece4d5" text-anchor="end">USD #{money(value)}</text>)
    end

    def money(value)
      whole = value.round.to_i.abs
      formatted = whole.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
      value.negative? ? "-#{formatted}" : formatted
    end
  end
end
