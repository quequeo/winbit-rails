import { useMemo, useState } from "react";
import { formatCurrencyAR, formatDateAR, formatNumberAR } from "../lib/formatters";

export type OperatingChartPoint = {
  date: string;
  percent: number;
  amountUsd: number;
};

const niceStep = (raw: number) => {
  if (!Number.isFinite(raw) || raw <= 0) return 1;
  const exp = Math.floor(Math.log10(raw));
  const base = 10 ** exp;
  const f = raw / base;
  const n = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
  return n * base;
};

const formatUsdTick = (v: number) => {
  const abs = Math.abs(v);
  if (abs >= 1_000_000) return `${Math.round(v / 100_000) / 10}m`;
  if (abs >= 1_000) return `${Math.round(v / 100) / 10}k`;
  return `${Math.round(v)}`;
};

export const OperatingDualChart = ({
  series,
  hideUsdAmounts = false,
}: {
  series: OperatingChartPoint[];
  hideUsdAmounts?: boolean;
}) => {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);

  const width = 900;
  const height = 280;
  const padX = 56;
  const padY = 22;
  const padRight = 44;

  const usdValues = series.map((p) => p.amountUsd);
  const minUsd = Math.min(0, ...usdValues);
  const maxUsd = Math.max(1, ...usdValues);
  const usdRange = Math.max(1, maxUsd - minUsd);

  const usdTicks = useMemo(() => {
    const step = niceStep(usdRange / 4);
    const start = Math.floor(minUsd / step) * step;
    const end = Math.ceil(maxUsd / step) * step;
    const ticks: number[] = [];
    for (let v = start; v <= end + step * 0.5; v += step) {
      ticks.push(v);
      if (ticks.length > 6) break;
    }
    return ticks.length >= 2 ? ticks : [minUsd, maxUsd];
  }, [minUsd, maxUsd, usdRange]);

  const zeroY = padY + (1 - (0 - minUsd) / usdRange) * (height - padY * 2);
  const plotWidth = width - padX - padRight;
  const barGap = series.length > 40 ? 1 : series.length > 20 ? 2 : 4;
  const barWidth = Math.max(
    3,
    plotWidth / Math.max(1, series.length) - barGap,
  );

  const bars = useMemo(() => {
    const n = series.length;
    const slot = plotWidth / Math.max(1, n);
    return series.map((point, idx) => {
      const x = padX + idx * slot + (slot - barWidth) / 2;
      const valueY =
        padY +
        (1 - (point.amountUsd - minUsd) / usdRange) * (height - padY * 2);
      const y = Math.min(valueY, zeroY);
      const h = Math.max(1, Math.abs(valueY - zeroY));
      return { x, y, height: h, ...point, index: idx };
    });
  }, [series, minUsd, usdRange, barWidth, zeroY, plotWidth]);

  const handleMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const svgX = ((e.clientX - rect.left) / rect.width) * width;

    let closest = bars[0] ?? null;
    let minDistance = Infinity;
    bars.forEach((bar) => {
      const center = bar.x + barWidth / 2;
      const distance = Math.abs(svgX - center);
      if (distance < minDistance) {
        minDistance = distance;
        closest = bar;
      }
    });

    if (!closest) return;
    setHoveredIndex(closest.index);
  };

  if (series.length < 1) {
    return (
      <div className="rounded-md border border-dashed border-b-default p-6 text-sm text-t-dim">
        No hay días operativos para mostrar el gráfico.
      </div>
    );
  }

  const hovered = hoveredIndex === null ? null : bars[hoveredIndex];
  const tooltipLeftPct = hovered
    ? ((hovered.x + barWidth / 2) / width) * 100
    : 0;
  const tooltipTopPct = hovered
    ? Math.max(4, ((hovered.y - 8) / height) * 100)
    : 0;

  return (
    <div className="relative w-full">
      <div className="mb-3 flex flex-wrap gap-4 text-xs text-t-muted">
        <span className="inline-flex items-center gap-2">
          <span className="h-3 w-3 rounded-sm bg-success" />
          Resultado USD positivo
        </span>
        <span className="inline-flex items-center gap-2">
          <span className="h-3 w-3 rounded-sm bg-error" />
          Resultado USD negativo
        </span>
      </div>

      <div className="relative w-full">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="h-72 w-full"
          role="img"
          aria-label="Resultado diario de operativa en columnas USD"
          preserveAspectRatio="none"
          onMouseMove={handleMouseMove}
          onMouseLeave={() => setHoveredIndex(null)}
        >
          {usdTicks.map((value) => {
            const y =
              padY + (1 - (value - minUsd) / usdRange) * (height - padY * 2);
            return (
              <g key={`usd-${value}`}>
                <line
                  x1={padX}
                  y1={y}
                  x2={width - padRight}
                  y2={y}
                  stroke="rgba(255,255,255,0.08)"
                  strokeWidth="1"
                />
                <text x={6} y={y + 3} fontSize="10" fill="#888888">
                  {hideUsdAmounts ? "••" : formatUsdTick(value)}
                </text>
              </g>
            );
          })}

          <line
            x1={padX}
            y1={zeroY}
            x2={width - padRight}
            y2={zeroY}
            stroke="rgba(255,255,255,0.25)"
            strokeWidth="1"
          />

          {bars.map((bar) => {
            const positive = bar.amountUsd >= 0;
            const isHovered = hoveredIndex === bar.index;
            return (
              <rect
                key={bar.date}
                x={bar.x}
                y={bar.y}
                width={barWidth}
                height={bar.height}
                rx={1.5}
                fill={positive ? "#9dd4cb" : "#d48080"}
                opacity={isHovered ? 1 : 0.85}
              />
            );
          })}
        </svg>

        {hovered ? (
          <div
            className="pointer-events-none absolute z-20 -translate-x-1/2 -translate-y-full rounded-lg bg-gray-900 px-3 py-2 text-xs text-white shadow-lg"
            style={{
              left: `${tooltipLeftPct}%`,
              top: `${tooltipTopPct}%`,
            }}
          >
            <div className="font-semibold">
              {formatDateAR(hovered.date, { time: false })}
            </div>
            <div className="mt-1 text-primary">
              {hideUsdAmounts ? "••••" : formatCurrencyAR(hovered.amountUsd)}
            </div>
            <div className="text-warning">
              {hovered.percent >= 0 ? "+" : ""}
              {formatNumberAR(hovered.percent)}%
            </div>
          </div>
        ) : null}
      </div>

      <div className="mt-2 flex items-center justify-between text-xs text-t-dim">
        <span>{formatDateAR(series[0]?.date || "", { time: false })}</span>
        <span>
          {formatDateAR(series[series.length - 1]?.date || "", { time: false })}
        </span>
      </div>
    </div>
  );
};
