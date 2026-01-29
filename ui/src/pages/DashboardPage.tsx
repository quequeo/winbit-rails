import { useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { formatCurrencyAR } from '../lib/formatters';

type AumPoint = {
  date: string; // YYYY-MM-DD
  totalAum: number;
};

type DashboardData = {
  data: {
    investorCount: number;
    pendingRequestCount: number;
    totalAum: number;
    aumSeries?: AumPoint[];
    strategyReturnYtdUsd?: number;
    strategyReturnYtdPercent?: number;
    strategyReturnAllUsd?: number;
    strategyReturnAllPercent?: number;
  };
};


type RangeKey = '7D' | '1M' | '3M' | '6M' | '1Y' | 'ALL';

const RANGE_OPTIONS: { key: RangeKey; label: string; days: number }[] = [
  { key: '7D', label: '7 días', days: 7 },
  { key: '1M', label: '1 mes', days: 30 },
  { key: '3M', label: '3 meses', days: 90 },
  { key: '6M', label: '6 meses', days: 180 },
  { key: '1Y', label: '1 año', days: 365 },
  // days=0 => backend interpreta "Todo desde el inicio"
  { key: 'ALL', label: 'Todo', days: 0 },
];

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

const formatDate = (dateStr: string) => {
  if (!dateStr) return '';
  const d = new Date(dateStr + 'T00:00:00.000Z');
  if (Number.isNaN(d.getTime())) return dateStr;
  const day = String(d.getUTCDate()).padStart(2, '0');
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  const year = d.getUTCFullYear();
  return `${day}/${month}/${year}`;
};

const AumLineChart = ({ series }: { series: AumPoint[] }) => {
  const [hoveredPoint, setHoveredPoint] = useState<{ x: number; y: number; date: string; totalAum: number; index: number } | null>(null);
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

    // Find the closest point by X coordinate (date), not by distance
    // This ensures we show the balance for the date the user is hovering over
    let closestPoint: typeof points[0] | null = null;
    let minDistance = Infinity;
    const hoverRadius = 30; // pixels for Y-axis tolerance

    points.forEach((point) => {
      const xDistance = Math.abs(svgX - point.x);
      const yDistance = Math.abs(svgY - point.y);
      // Prioritize X distance (date), but also check Y is close
      if (xDistance < hoverRadius && yDistance < hoverRadius) {
        const distance = xDistance * 2 + yDistance; // Weight X more heavily
        if (distance < minDistance) {
          minDistance = distance;
          closestPoint = point;
        }
      }
    });

    // If no point found by distance, find the closest by X (date) only
    if (!closestPoint && points.length > 0) {
      closestPoint = points.reduce((closest, point) => {
        const xDist = Math.abs(svgX - point.x);
        const closestDist = Math.abs(svgX - closest.x);
        return xDist < closestDist ? point : closest;
      });
    }

    if (closestPoint) {
      setHoveredPoint(closestPoint);
      // Position tooltip near cursor, but adjust if too close to edges
      const tooltipWidth = 150; // approximate tooltip width
      const tooltipHeight = 60; // approximate tooltip height
      let x = e.clientX + 15;
      let y = e.clientY - tooltipHeight - 10;

      // Adjust if tooltip would go off right edge
      if (x + tooltipWidth > window.innerWidth) {
        x = e.clientX - tooltipWidth - 15;
      }
      // Adjust if tooltip would go off left edge
      if (x < 0) {
        x = 10;
      }
      // Adjust if tooltip would go off top edge
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

  const line = points.map((pt) => `${pt.x.toFixed(2)},${pt.y.toFixed(2)}`).join(' ');
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
            <stop offset="0%" stopColor="#60a5fa" stopOpacity="0.28" />
            <stop offset="100%" stopColor="#60a5fa" stopOpacity="0.02" />
          </linearGradient>
        </defs>

        {tickValues.map((v) => {
          const yNorm = (v - minV) / range;
          const y = padY + (1 - yNorm) * (height - padY * 2);

          return (
            <g key={v}>
              <line x1={padX} y1={y} x2={width - padX} y2={y} stroke="#e5e7eb" strokeWidth="1" opacity="0.6" />
              <text x={6} y={y + 3} fontSize="10" fill="#6b7280">
                {formatTick(v)}
              </text>
            </g>
          );
        })}

        <line x1={padX} y1={height - padY} x2={width - padX} y2={height - padY} stroke="#e5e7eb" strokeWidth="1" />

        <polyline points={area} fill="url(#aumArea)" stroke="none" />
        <polyline points={line} fill="none" stroke="#2563eb" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />

        {/* Invisible larger circles for hover detection */}
        {points.map((point, idx) => (
          <circle
            key={`hover-${idx}`}
            cx={point.x}
            cy={point.y}
            r="8"
            fill="transparent"
            stroke="none"
            style={{ cursor: 'pointer' }}
          />
        ))}

        {/* Visible circle on hover only */}
        {hoveredPoint && (
          <circle
            cx={hoveredPoint.x}
            cy={hoveredPoint.y}
            r="5"
            fill="#1e40af"
            style={{ transition: 'r 0.2s, fill 0.2s' }}
          />
        )}

        {/* Vertical line on hover */}
        {hoveredPoint && (
          <line
            x1={hoveredPoint.x}
            y1={padY}
            x2={hoveredPoint.x}
            y2={height - padY}
            stroke="#94a3b8"
            strokeWidth="1"
            strokeDasharray="4,4"
            opacity="0.5"
          />
        )}
      </svg>

      {/* Tooltip */}
      {hoveredPoint && (
        <div
          className="fixed bg-gray-900 text-white text-xs rounded-lg px-3 py-2 shadow-lg pointer-events-none z-50"
          style={{
            left: `${tooltipPosition.x}px`,
            top: `${tooltipPosition.y}px`,
            transform: 'translate(-50%, -100%)',
          }}
        >
          <div className="font-semibold">{formatDate(hoveredPoint.date)}</div>
          <div className="text-blue-300 mt-1">{formatCurrencyAR(hoveredPoint.totalAum)}</div>
        </div>
      )}

      <div className="mt-2 flex items-center justify-between text-xs text-gray-500">
        <span>{formatDate(series[0]?.date || '')}</span>
        <span>{formatDate(series[series.length - 1]?.date || '')}</span>
      </div>
    </div>
  );
};

export const DashboardPage = () => {
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [rangeKey, setRangeKey] = useState<RangeKey>('3M');
  const year = useMemo(() => new Date().getFullYear(), []);

  const days = useMemo(() => {
    return RANGE_OPTIONS.find((r) => r.key === rangeKey)?.days ?? 90;
  }, [rangeKey]);

  useEffect(() => {
    let isMounted = true;

    api
      .getAdminDashboard({ days })
      .then((res) => {
        if (isMounted) {
          setData(res as DashboardData);
          setError(null);
        }
      })
      .catch((e) => {
        if (isMounted) setError(e.message);
      });

    return () => {
      isMounted = false;
    };
  }, [days]);

  const aumSeries = data?.data?.aumSeries || [];

  const rangeSubtitle = useMemo(() => {
    const opt = RANGE_OPTIONS.find((r) => r.key === rangeKey);
    if (!opt) return '';
    if (opt.key === 'ALL') return 'Todo desde el inicio';
    return `Últimos ${opt.label}`;
  }, [rangeKey]);

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>

      <div className="grid gap-6 md:grid-cols-3">
        <div className="rounded-lg bg-white p-6 shadow transform transition-transform duration-200 ease-out hover:-translate-y-1 hover:shadow-lg">
          <p className="text-sm font-medium text-gray-600">Total Inversores</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">{data.data.investorCount}</p>
        </div>
        <div className="rounded-lg bg-white p-6 shadow transform transition-transform duration-200 ease-out hover:-translate-y-1 hover:shadow-lg">
          <p className="text-sm font-medium text-gray-600">Capital Total Administrado</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">{formatCurrencyAR(data.data.totalAum)}</p>
        </div>
        <div className="rounded-lg bg-white p-6 shadow transform transition-transform duration-200 ease-out hover:-translate-y-1 hover:shadow-lg">
          <p className="text-sm font-medium text-gray-600">Solicitudes Pendientes</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">{data.data.pendingRequestCount}</p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-4">
        <div className="rounded-lg bg-white p-6 shadow transform transition-transform duration-200 ease-out hover:-translate-y-1 hover:shadow-lg">
          <p className="text-sm font-medium text-gray-600">Resultado estrategia {year} (USD)</p>
          <p className="mt-2 text-2xl font-bold text-gray-900">{formatCurrencyAR(data.data.strategyReturnYtdUsd ?? 0)}</p>
        </div>
        <div className="rounded-lg bg-white p-6 shadow transform transition-transform duration-200 ease-out hover:-translate-y-1 hover:shadow-lg">
          <p className="text-sm font-medium text-gray-600">Resultado estrategia {year} (%)</p>
          <p className="mt-2 text-2xl font-bold text-gray-900">
            {data.data.strategyReturnYtdPercent !== undefined
              ? `${data.data.strategyReturnYtdPercent >= 0 ? '+' : ''}${data.data.strategyReturnYtdPercent.toFixed(2)}%`
              : '0.00%'}
          </p>
        </div>
        <div className="rounded-lg bg-white p-6 shadow transform transition-transform duration-200 ease-out hover:-translate-y-1 hover:shadow-lg">
          <p className="text-sm font-medium text-gray-600">Resultado estrategia histórico (USD)</p>
          <p className="mt-2 text-2xl font-bold text-gray-900">{formatCurrencyAR(data.data.strategyReturnAllUsd ?? 0)}</p>
        </div>
        <div className="rounded-lg bg-white p-6 shadow transform transition-transform duration-200 ease-out hover:-translate-y-1 hover:shadow-lg">
          <p className="text-sm font-medium text-gray-600">Resultado estrategia histórico (%)</p>
          <p className="mt-2 text-2xl font-bold text-gray-900">
            {data.data.strategyReturnAllPercent !== undefined
              ? `${data.data.strategyReturnAllPercent >= 0 ? '+' : ''}${data.data.strategyReturnAllPercent.toFixed(2)}%`
              : '0.00%'}
          </p>
        </div>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Evolución del capital total administrado</h2>
            <p className="text-sm text-gray-500">{rangeSubtitle}</p>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap gap-2" role="group" aria-label="Rango de tiempo del gráfico">
          {RANGE_OPTIONS.map((opt) => {
            const isActive = opt.key === rangeKey;
            return (
              <button
                key={opt.key}
                type="button"
                onClick={() => setRangeKey(opt.key)}
                className={`rounded-full border px-3 py-1 text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-[#58b098] text-white border-[#58b098]'
                    : 'bg-white text-gray-700 border-gray-200 hover:border-[#58b098] hover:text-[#58b098]'
                }`}
              >
                {opt.label}
              </button>
            );
          })}
        </div>

        <div className="mt-4">
          {aumSeries.length >= 2 ? (
            <AumLineChart series={aumSeries} />
          ) : (
            <div className="rounded-md border border-dashed border-gray-200 p-6 text-sm text-gray-500">
              Sin datos históricos todavía.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
