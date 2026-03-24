import { useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { formatCurrencyAR } from "../lib/formatters";
import { AumLineChart, type AumPoint } from "../components/AumLineChart";

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

type RangeKey = "7D" | "1M" | "3M" | "6M" | "1Y" | "ALL";

const RANGE_OPTIONS: { key: RangeKey; label: string; days: number }[] = [
  { key: "7D", label: "7 días", days: 7 },
  { key: "1M", label: "1 mes", days: 30 },
  { key: "3M", label: "3 meses", days: 90 },
  { key: "6M", label: "6 meses", days: 180 },
  { key: "1Y", label: "1 año", days: 365 },
  { key: "ALL", label: "Todo", days: 0 },
];

export const DashboardPage = () => {
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [rangeKey, setRangeKey] = useState<RangeKey>("3M");
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
    if (!opt) return "";
    if (opt.key === "ALL") return "Todo desde el inicio";
    return `Últimos ${opt.label}`;
  }, [rangeKey]);

  if (error) return <div className="text-error">{error}</div>;
  if (!data) return <div className="text-t-muted">Cargando...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-t-primary">Dashboard</h1>

      <div className="grid gap-6 md:grid-cols-3">
        <div className="admin-card p-6">
          <p className="text-sm font-medium text-t-muted">Total Inversores</p>
          <p className="mt-2 text-3xl font-bold text-t-primary">
            {data.data.investorCount}
          </p>
        </div>
        <div className="admin-card p-6">
          <p className="text-sm font-medium text-t-muted">
            Capital Total Administrado
          </p>
          <p className="mt-2 text-3xl font-bold text-t-primary">
            {formatCurrencyAR(data.data.totalAum)}
          </p>
        </div>
        <div className="admin-card p-6">
          <p className="text-sm font-medium text-t-muted">
            Solicitudes Pendientes
          </p>
          <p className="mt-2 text-3xl font-bold text-t-primary">
            {data.data.pendingRequestCount}
          </p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-4">
        <div className="admin-card p-6">
          <p className="text-sm font-medium text-t-muted">
            Resultado estrategia {year} (USD)
          </p>
          <p className="mt-2 text-2xl font-bold text-t-primary">
            {formatCurrencyAR(data.data.strategyReturnYtdUsd ?? 0)}
          </p>
        </div>
        <div className="admin-card p-6">
          <p className="text-sm font-medium text-t-muted">
            Resultado estrategia {year} (%)
          </p>
          <p className="mt-2 text-2xl font-bold text-t-primary">
            {data.data.strategyReturnYtdPercent !== undefined
              ? `${data.data.strategyReturnYtdPercent >= 0 ? "+" : ""}${data.data.strategyReturnYtdPercent.toFixed(2)}%`
              : "0.00%"}
          </p>
        </div>
        <div className="admin-card p-6">
          <p className="text-sm font-medium text-t-muted">
            Resultado estrategia histórico (USD)
          </p>
          <p className="mt-2 text-2xl font-bold text-t-primary">
            {formatCurrencyAR(data.data.strategyReturnAllUsd ?? 0)}
          </p>
        </div>
        <div className="admin-card p-6">
          <p className="text-sm font-medium text-t-muted">
            Resultado estrategia histórico (%)
          </p>
          <p className="mt-2 text-2xl font-bold text-t-primary">
            {data.data.strategyReturnAllPercent !== undefined
              ? `${data.data.strategyReturnAllPercent >= 0 ? "+" : ""}${data.data.strategyReturnAllPercent.toFixed(2)}%`
              : "0.00%"}
          </p>
        </div>
      </div>

      <div className="admin-card p-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 className="text-lg font-semibold text-t-primary">
              Evolución del capital total administrado
            </h2>
            <p className="text-sm text-t-dim">{rangeSubtitle}</p>
          </div>
        </div>

        <div
          className="mt-4 flex flex-wrap gap-2"
          role="group"
          aria-label="Rango de tiempo del gráfico"
        >
          {RANGE_OPTIONS.map((opt) => {
            const isActive = opt.key === rangeKey;
            return (
              <button
                key={opt.key}
                type="button"
                onClick={() => setRangeKey(opt.key)}
                className={`rounded-full border px-3 py-1 text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-primary text-white border-primary"
                    : "bg-dark-card text-t-muted border-b-default hover:border-primary hover:text-primary"
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
            <div className="rounded-md border border-dashed border-b-default p-6 text-sm text-t-dim">
              Sin datos históricos todavía.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
