import { useMemo, useState } from "react";
import { formatCurrencyAR, formatDateAR } from "../lib/formatters";

export type AumPoint = {
  date: string;
  totalAum: number;
};

const niceStep = (raw: number) => {
  if (!Number.isFinite(raw) || raw <= 0) return 1;
  const exp = Math.floor(Math.log10(raw));
  const base = 10 ** exp;
  const f = raw / base;
  const n = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
  return n * base;
};

const formatTick = (v: number) => {
  const abs = Math.abs(v);
  if (abs >= 1_000_000) return `${Math.round(v / 100_000) / 10}m`;
  if (abs >= 1_000) return `${Math.round(v / 100) / 10}k`;
  return `${Math.round(v)}`;
};

const formatDate = (dateStr: string) => formatDateAR(dateStr, { time: false });

export const AumLineChart = ({ series }: { series: AumPoint[] }) => {
  const [hoveredPoint, setHoveredPoint] = useState<{
    x: number;
    y: number;
    date: string;
    totalAum: number;
    index: number;
  } | null>(null);
  const [tooltipPosition, setTooltipPosition] = useState({ x: 0, y: 0 });
  const width = 900;
  const height = 240;
  const padX = 52;
  const padY = 18;

  const values = series.map((p) => p.totalAum);
  const minV = Math.min(...values);
  const maxV = Math.max(...values);
  const range = Math.max(1, maxV - minV);

  const tickValues = useMemo(() => {
    const step = niceStep(range / 4);
    const startV = Math.floor(minV / step) * step;
    const endV = Math.ceil(maxV / step) * step;

    const ticks: number[] = [];
    for (let v = startV; v <= endV + step * 0.5; v += step) {
      ticks.push(v);
      if (ticks.length > 6) break;
    }

    return ticks.length >= 2 ? ticks : [minV, maxV];
  }, [minV, maxV, range]);

  const points = useMemo(() => {
    const n = series.length;
    return series.map((p, idx) => {
      const x = padX + (idx / Math.max(1, n - 1)) * (width - padX * 2);
      const yNorm = (p.totalAum - minV) / range;
      const y = padY + (1 - yNorm) * (height - padY * 2);
      return { x, y, date: p.date, totalAum: p.totalAum, index: idx };
    });
  }, [series, minV, range]);

  const handleMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const svgX = ((e.clientX - rect.left) / rect.width) * width;
    const svgY = ((e.clientY - rect.top) / rect.height) * height;

    let closestPoint: (typeof points)[0] | null = null;
    let minDistance = Infinity;
    const hoverRadius = 30;

    points.forEach((point) => {
      const xDistance = Math.abs(svgX - point.x);
      const yDistance = Math.abs(svgY - point.y);
      if (xDistance < hoverRadius && yDistance < hoverRadius) {
        const distance = xDistance * 2 + yDistance;
        if (distance < minDistance) {
          minDistance = distance;
          closestPoint = point;
        }
      }
    });

    if (!closestPoint && points.length > 0) {
      closestPoint = points.reduce((closest, point) => {
        const xDist = Math.abs(svgX - point.x);
        const closestDist = Math.abs(svgX - closest.x);
        return xDist < closestDist ? point : closest;
      });
    }

    if (closestPoint) {
      setHoveredPoint(closestPoint);
      const tooltipWidth = 150;
      const tooltipHeight = 60;
      let x = e.clientX + 15;
      let y = e.clientY - tooltipHeight - 10;

      if (x + tooltipWidth > window.innerWidth) {
        x = e.clientX - tooltipWidth - 15;
      }
      if (x < 0) {
        x = 10;
      }
      if (y < 0) {
        y = e.clientY + 20;
      }

      setTooltipPosition({ x, y });
    } else {
      setHoveredPoint(null);
    }
  };

  const handleMouseLeave = () => {
    setHoveredPoint(null);
  };

  const line = points
    .map((pt) => `${pt.x.toFixed(2)},${pt.y.toFixed(2)}`)
    .join(" ");
  const area = `${padX},${height - padY} ${line} ${width - padX},${height - padY}`;

  return (
    <div className="w-full relative">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="h-56 w-full"
        role="img"
        aria-label="Evolución del capital total administrado"
        preserveAspectRatio="none"
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
      >
        <defs>
          <linearGradient id="aumArea" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#65a7a5" stopOpacity="0.28" />
            <stop offset="100%" stopColor="#65a7a5" stopOpacity="0.02" />
          </linearGradient>
        </defs>

        {tickValues.map((v) => {
          const yNorm = (v - minV) / range;
          const y = padY + (1 - yNorm) * (height - padY * 2);

          return (
            <g key={v}>
              <line
                x1={padX}
                y1={y}
                x2={width - padX}
                y2={y}
                stroke="rgba(255,255,255,0.08)"
                strokeWidth="1"
                opacity="0.6"
              />
              <text x={6} y={y + 3} fontSize="10" fill="#888888">
                {formatTick(v)}
              </text>
            </g>
          );
        })}

        <line
          x1={padX}
          y1={height - padY}
          x2={width - padX}
          y2={height - padY}
          stroke="rgba(255,255,255,0.08)"
          strokeWidth="1"
        />

        <polyline points={area} fill="url(#aumArea)" stroke="none" />
        <polyline
          points={line}
          fill="none"
          stroke="#65a7a5"
          strokeWidth="2"
          strokeLinejoin="round"
          strokeLinecap="round"
        />

        {points.map((point, idx) => (
          <circle
            key={`hover-${idx}`}
            cx={point.x}
            cy={point.y}
            r="8"
            fill="transparent"
            stroke="none"
            style={{ cursor: "pointer" }}
          />
        ))}

        {hoveredPoint && (
          <circle
            cx={hoveredPoint.x}
            cy={hoveredPoint.y}
            r="5"
            fill="#65a7a5"
            style={{ transition: "r 0.2s, fill 0.2s" }}
          />
        )}

        {hoveredPoint && (
          <line
            x1={hoveredPoint.x}
            y1={padY}
            x2={hoveredPoint.x}
            y2={height - padY}
            stroke="#65a7a5"
            strokeWidth="1"
            strokeDasharray="4,4"
            opacity="0.5"
          />
        )}
      </svg>

      {hoveredPoint && (
        <div
          className="fixed bg-gray-900 text-white text-xs rounded-lg px-3 py-2 shadow-lg pointer-events-none z-50"
          style={{
            left: `${tooltipPosition.x}px`,
            top: `${tooltipPosition.y}px`,
            transform: "translate(-50%, -100%)",
          }}
        >
          <div className="font-semibold">{formatDate(hoveredPoint.date)}</div>
          <div className="text-primary mt-1">
            {formatCurrencyAR(hoveredPoint.totalAum)}
          </div>
        </div>
      )}

      <div className="mt-2 flex items-center justify-between text-xs text-t-dim">
        <span>{formatDate(series[0]?.date || "")}</span>
        <span>{formatDate(series[series.length - 1]?.date || "")}</span>
      </div>
    </div>
  );
};
