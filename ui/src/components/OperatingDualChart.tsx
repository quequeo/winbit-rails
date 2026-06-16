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
}: {
  series: OperatingChartPoint[];
}) => {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const [tooltipPosition, setTooltipPosition] = useState({ x: 0, y: 0 });

  const width = 900;
  const height = 260;
  const padX = 56;
  const padY = 22;
  const padRight = 44;

  const usdValues = series.map((p) => p.amountUsd);
  const pctValues = series.map((p) => p.percent);

  const minUsd = Math.min(0, ...usdValues);
  const maxUsd = Math.max(1, ...usdValues);
  const usdRange = Math.max(1, maxUsd - minUsd);

  const minPct = Math.min(0, ...pctValues);
  const maxPct = Math.max(0.1, ...pctValues);
  const pctRange = Math.max(0.1, maxPct - minPct);

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

  const pctTicks = useMemo(() => {
    const step = niceStep(pctRange / 4);
    const start = Math.floor(minPct / step) * step;
    const end = Math.ceil(maxPct / step) * step;
    const ticks: number[] = [];
    for (let v = start; v <= end + step * 0.5; v += step) {
      ticks.push(Number(v.toFixed(2)));
      if (ticks.length > 6) break;
    }
    return ticks.length >= 2 ? ticks : [minPct, maxPct];
  }, [minPct, maxPct, pctRange]);

  const points = useMemo(() => {
    const n = series.length;
    return series.map((point, idx) => {
      const x =
        padX + (idx / Math.max(1, n - 1)) * (width - padX - padRight);
      const usdY =
        padY + (1 - (point.amountUsd - minUsd) / usdRange) * (height - padY * 2);
      const pctY =
        padY + (1 - (point.percent - minPct) / pctRange) * (height - padY * 2);
      return { x, usdY, pctY, ...point, index: idx };
    });
  }, [series, minUsd, usdRange, minPct, pctRange]);

  const usdLine = points
    .map((point) => `${point.x.toFixed(2)},${point.usdY.toFixed(2)}`)
    .join(" ");
  const pctLine = points
    .map((point) => `${point.x.toFixed(2)},${point.pctY.toFixed(2)}`)
    .join(" ");

  const handleMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const svgX = ((e.clientX - rect.left) / rect.width) * width;

    let closest = points[0] ?? null;
    let minDistance = Infinity;
    points.forEach((point) => {
      const distance = Math.abs(svgX - point.x);
      if (distance < minDistance) {
        minDistance = distance;
        closest = point;
      }
    });

    if (!closest) return;
    setHoveredIndex(closest.index);
    setTooltipPosition({ x: e.clientX + 12, y: e.clientY - 12 });
  };

  if (series.length < 2) {
    return (
      <div className="rounded-md border border-dashed border-b-default p-6 text-sm text-t-dim">
        Se necesitan al menos 2 días operativos para mostrar el gráfico.
      </div>
    );
  }

  const hovered = hoveredIndex === null ? null : points[hoveredIndex];

  return (
    <div className="relative w-full">
      <div className="mb-3 flex flex-wrap gap-4 text-xs text-t-muted">
        <span className="inline-flex items-center gap-2">
          <span className="h-0.5 w-5 bg-primary" />
          Resultado USD
        </span>
        <span className="inline-flex items-center gap-2">
          <span className="h-0.5 w-5 bg-warning" />
          Resultado %
        </span>
      </div>

      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="h-64 w-full"
        role="img"
        aria-label="Evolución diaria de operativa en USD y porcentaje"
        preserveAspectRatio="none"
        onMouseMove={handleMouseMove}
        onMouseLeave={() => setHoveredIndex(null)}
      >
        {usdTicks.map((value) => {
          const y = padY + (1 - (value - minUsd) / usdRange) * (height - padY * 2);
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
                {formatUsdTick(value)}
              </text>
            </g>
          );
        })}

        {pctTicks.map((value) => {
          const y = padY + (1 - (value - minPct) / pctRange) * (height - padY * 2);
          return (
            <text
              key={`pct-${value}`}
              x={width - padRight + 6}
              y={y + 3}
              fontSize="10"
              fill="#d4bf82"
            >
              {formatNumberAR(value)}%
            </text>
          );
        })}

        <polyline
          points={usdLine}
          fill="none"
          stroke="#65a7a5"
          strokeWidth="2"
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        <polyline
          points={pctLine}
          fill="none"
          stroke="#d4bf82"
          strokeWidth="2"
          strokeLinejoin="round"
          strokeLinecap="round"
          strokeDasharray="6 4"
        />

        {hovered ? (
          <>
            <line
              x1={hovered.x}
              y1={padY}
              x2={hovered.x}
              y2={height - padY}
              stroke="#65a7a5"
              strokeWidth="1"
              strokeDasharray="4 4"
              opacity="0.5"
            />
            <circle cx={hovered.x} cy={hovered.usdY} r="4" fill="#65a7a5" />
            <circle cx={hovered.x} cy={hovered.pctY} r="4" fill="#d4bf82" />
          </>
        ) : null}
      </svg>

      {hovered ? (
        <div
          className="fixed z-50 rounded-lg bg-gray-900 px-3 py-2 text-xs text-white shadow-lg pointer-events-none"
          style={{ left: tooltipPosition.x, top: tooltipPosition.y }}
        >
          <div className="font-semibold">
            {formatDateAR(hovered.date, { time: false })}
          </div>
          <div className="mt-1 text-primary">
            {formatCurrencyAR(hovered.amountUsd)}
          </div>
          <div className="text-warning">
            {hovered.percent >= 0 ? "+" : ""}
            {formatNumberAR(hovered.percent)}%
          </div>
        </div>
      ) : null}

      <div className="mt-2 flex items-center justify-between text-xs text-t-dim">
        <span>{formatDateAR(series[0]?.date || "", { time: false })}</span>
        <span>
          {formatDateAR(series[series.length - 1]?.date || "", { time: false })}
        </span>
      </div>
    </div>
  );
};
