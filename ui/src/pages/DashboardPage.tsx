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

const AumLineChart = ({ series }: { series: AumPoint[] }) => {
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
      return { x, y };
    });
  }, [series, minV, range]);

  const line = points.map((pt) => `${pt.x.toFixed(2)},${pt.y.toFixed(2)}`).join(' ');
  const area = `${padX},${height - padY} ${line} ${width - padX},${height - padY}`;

  return (
    <div className="w-full">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="h-56 w-full"
        role="img"
        aria-label="Evolución del capital total administrado"
        preserveAspectRatio="none"
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

        {points.length > 0 ? (
          <circle cx={points[points.length - 1].x} cy={points[points.length - 1].y} r="3" fill="#1d4ed8" />
        ) : null}
      </svg>

      <div className="mt-2 flex items-center justify-between text-xs text-gray-500">
        <span>{series[0]?.date}</span>
        <span>{series[series.length - 1]?.date}</span>
      </div>
    </div>
  );
};

export const DashboardPage = () => {
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [rangeKey, setRangeKey] = useState<RangeKey>('3M');

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

  const aumStats = useMemo(() => {
    if (!aumSeries || aumSeries.length < 2) return null;
    const first = aumSeries[0].totalAum;
    const last = aumSeries[aumSeries.length - 1].totalAum;
    const delta = last - first;
    const deltaPct = first > 0 ? (delta / first) * 100 : 0;

    return {
      first,
      last,
      delta,
      deltaPct,
    };
  }, [aumSeries]);

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

      <div className="rounded-lg bg-white p-6 shadow">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Evolución del capital total administrado</h2>
            <p className="text-sm text-gray-500">{rangeSubtitle}</p>
          </div>

          {aumStats ? (
            <div className="text-sm text-gray-700">
              <span className="font-medium">{formatCurrencyAR(aumStats.first)}</span>
              <span className="mx-2 text-gray-300">→</span>
              <span className="font-medium">{formatCurrencyAR(aumStats.last)}</span>
              <span
                className={`ml-3 font-semibold ${aumStats.delta >= 0 ? 'text-green-700' : 'text-red-700'}`}
                title="Variación del período"
              >
                {aumStats.delta >= 0 ? '+' : ''}
                {formatCurrencyAR(aumStats.delta)}
                {aumStats.first > 0 ? ` (${aumStats.deltaPct.toFixed(2)}%)` : ''}
              </span>
            </div>
          ) : null}
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
