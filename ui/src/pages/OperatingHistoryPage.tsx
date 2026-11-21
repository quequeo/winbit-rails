import { useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { Button } from "../components/ui/Button";
import { DatePicker } from "../components/ui/DatePicker";
import {
  formatCurrencyAR,
  formatDateAR,
  formatNumberAR,
} from "../lib/formatters";
import {
  OperatingDualChart,
  type OperatingChartPoint,
} from "../components/OperatingDualChart";
import { exportOperatingToExcel } from "../lib/exportOperatingToExcel";
import { OperatingAsset } from "../components/OperatingAsset";
import {
  countStrategyResults,
  type StrategyResultCounts,
} from "../lib/strategyOperationTone";
import {
  DayCaptureCarousel,
  type DayCaptureItem,
} from "../components/DayCaptureCarousel";

type HistoryRow = {
  id: string;
  date: string;
  percent: number;
  amount_usd?: number;
  notes?: string | null;
  created_at: string;
};

type DayOperation = {
  id: string;
  operationDate: string;
  asset: string;
  direction?: string | null;
};

type MonthlySummaryRow = {
  month: string;
  days: number;
  compounded_percent: number;
  total_usd?: number;
  first_date: string;
  last_date: string;
};

const MONTH_WINDOW_OPTIONS = [1, 2, 3, 6, 12];

// Detalle diario: mismo criterio que la app (positivo en verde con "+",
// negativo en rojo, cero en gris) para leer el resultado de un vistazo.
const resultTone = (value: number) =>
  value > 0 ? "text-success" : value < 0 ? "text-error" : "text-t-dim";
const signedUsd = (value: number) =>
  `${value > 0 ? "+" : ""}${formatCurrencyAR(value)}`;
const signedPercent = (value: number) =>
  `${value > 0 ? "+" : ""}${formatNumberAR(value)}%`;
const HIDE_USD_STORAGE_KEY = "operatingHistory.hideUsdAmounts";
const USD_MASK = "••••";

const readHideUsdPreference = (): boolean => {
  try {
    return window.localStorage.getItem(HIDE_USD_STORAGE_KEY) === "1";
  } catch {
    return false;
  }
};

const writeHideUsdPreference = (hidden: boolean) => {
  try {
    window.localStorage.setItem(HIDE_USD_STORAGE_KEY, hidden ? "1" : "0");
  } catch {
    // ignore storage failures (private mode, etc.)
  }
};

const EyeIcon = ({ className }: { className?: string }) => (
  <svg
    className={className || ""}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
  >
    <path
      d="M2.5 12s3.5-7 9.5-7 9.5 7 9.5 7-3.5 7-9.5 7-9.5-7-9.5-7Z"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const EyeOffIcon = ({ className }: { className?: string }) => (
  <svg
    className={className || ""}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
  >
    <path
      d="M3 3l18 18"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
    />
    <path
      d="M10.6 10.6a3.5 3.5 0 0 0 4.8 4.8"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <path
      d="M9.9 5.2A10.4 10.4 0 0 1 12 5c6 0 9.5 7 9.5 7a16.6 16.6 0 0 1-3.2 3.9M6.1 6.1C3.9 7.7 2.5 12 2.5 12s3.5 7 9.5 7c1.3 0 2.5-.3 3.6-.7"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const CameraIcon = ({ className }: { className?: string }) => (
  <svg
    className={className || ""}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
  >
    <path
      d="M4.5 8.5h2.2l1.1-2h8.4l1.1 2H19.5A1.5 1.5 0 0 1 21 10v8.5a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5V10a1.5 1.5 0 0 1 1.5-1.5Z"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinejoin="round"
    />
    <circle cx="12" cy="14" r="3.2" stroke="currentColor" strokeWidth="1.8" />
  </svg>
);

const monthLabel = (ym: string) => {
  const m = String(ym || "").match(/^(\d{4})-(\d{2})$/);
  if (!m) return ym;
  const yyyy = m[1];
  const mm = Number(m[2]);
  const names = [
    "Ene",
    "Feb",
    "Mar",
    "Abr",
    "May",
    "Jun",
    "Jul",
    "Ago",
    "Sep",
    "Oct",
    "Nov",
    "Dic",
  ];
  return `${names[mm - 1] || m[2]} ${yyyy}`;
};

export const OperatingHistoryPage = () => {
  const [history, setHistory] = useState<HistoryRow[]>([]);
  const [historyMeta, setHistoryMeta] = useState<{
    page: number;
    per_page: number;
    total: number;
    total_pages: number;
  } | null>(null);
  const [historyPage, setHistoryPage] = useState(1);
  const historyPerPage = 10;

  const [monthlySummary, setMonthlySummary] = useState<MonthlySummaryRow[]>([]);
  const [monthlyOffset, setMonthlyOffset] = useState(0);
  const [monthsWindow, setMonthsWindow] = useState(3);
  const [chartSeries, setChartSeries] = useState<OperatingChartPoint[]>([]);
  const [resultCounts, setResultCounts] = useState<StrategyResultCounts>({
    positive: 0,
    negative: 0,
    bePlus: 0,
    beMinus: 0,
  });
  const [loadingChart, setLoadingChart] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [loadingHistory, setLoadingHistory] = useState(false);
  const [loadingMonthly, setLoadingMonthly] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hideUsdAmounts, setHideUsdAmounts] = useState(readHideUsdPreference);
  const [operationsByDate, setOperationsByDate] = useState<
    Record<string, DayOperation[]>
  >({});
  const [captureCounts, setCaptureCounts] = useState<Record<string, number>>(
    {},
  );
  const [carouselOpen, setCarouselOpen] = useState(false);
  const [carouselDate, setCarouselDate] = useState<string | null>(null);
  const [carouselCaptures, setCarouselCaptures] = useState<DayCaptureItem[]>(
    [],
  );
  const [loadingCaptures, setLoadingCaptures] = useState(false);
  const [exportFrom, setExportFrom] = useState(() => {
    const d = new Date();
    d.setMonth(d.getMonth() - 2);
    return d.toISOString().slice(0, 10);
  });
  const [exportTo, setExportTo] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );
  const [chartFrom, setChartFrom] = useState(() => {
    const d = new Date();
    d.setMonth(d.getMonth() - 2);
    return d.toISOString().slice(0, 10);
  });
  const [chartTo, setChartTo] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );

  const toggleHideUsdAmounts = () => {
    setHideUsdAmounts((prev) => {
      const next = !prev;
      writeHideUsdPreference(next);
      return next;
    });
  };

  const loadCaptureCounts = async () => {
    try {
      const res = (await api.getOperationDayCaptureCounts()) as {
        data?: { date: string; count: number }[];
      } | null;
      const next: Record<string, number> = {};
      for (const row of res?.data ?? []) {
        next[row.date] = row.count;
      }
      setCaptureCounts(next);
    } catch {
      // Capturas son opcionales; no bloquear el historial.
    }
  };

  const openDayCaptures = async (date: string) => {
    try {
      setLoadingCaptures(true);
      setError(null);
      const res = (await api.getOperationDayCapturesForDate(date)) as {
        data?: DayCaptureItem[];
      } | null;
      const items = res?.data ?? [];
      if (items.length === 0) {
        setError(`No hay capturas para ${date}.`);
        return;
      }
      setCarouselDate(date);
      setCarouselCaptures(items);
      setCarouselOpen(true);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Error al cargar capturas");
    } finally {
      setLoadingCaptures(false);
    }
  };

  const loadHistory = async (page: number) => {
    try {
      setLoadingHistory(true);
      setError(null);
      const res = (await api.getDailyOperatingResults({
        page,
        per_page: historyPerPage,
      })) as {
        data?: HistoryRow[];
        meta?: {
          page: number;
          per_page: number;
          total: number;
          total_pages: number;
        };
      } | null;
      const rows = res?.data ?? [];
      setHistory(rows);
      setHistoryMeta(res?.meta ?? null);
      void loadDayOperations(rows);
      setHistoryPage(page);
      void loadCaptureCounts();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Error al cargar historial");
    } finally {
      setLoadingHistory(false);
    }
  };

  // Operación de cada día de la página (activo y dirección), para el resumen
  // del Detalle diario. El detalle completo está en "Operaciones (detalle)".
  const loadDayOperations = async (rows: HistoryRow[]) => {
    if (rows.length === 0) {
      setOperationsByDate({});
      return;
    }
    const dates = rows.map((row) => row.date).sort();
    try {
      const res = (await api.getStrategyOperations({
        from: dates[0],
        to: dates[dates.length - 1],
        per_page: 200,
      })) as { data?: DayOperation[] } | null;
      const byDate: Record<string, DayOperation[]> = {};
      for (const op of res?.data ?? []) {
        (byDate[op.operationDate] ||= []).push(op);
      }
      setOperationsByDate(byDate);
    } catch {
      setOperationsByDate({});
    }
  };

  const loadMonthly = async (offset: number, months = monthsWindow) => {
    try {
      setLoadingMonthly(true);
      const res = (await api.getDailyOperatingMonthlySummary({
        months,
        offset,
      })) as {
        data?: MonthlySummaryRow[];
      } | null;
      setMonthlySummary(res?.data ?? []);
    } catch {
      // ignore
    } finally {
      setLoadingMonthly(false);
    }
  };

  const loadChartRange = async (from = chartFrom, to = chartTo) => {
    if (!from || !to) {
      setError("Completá desde y hasta para el gráfico.");
      return;
    }
    if (from > to) {
      setError("La fecha desde no puede ser posterior a la fecha hasta.");
      return;
    }
    try {
      setLoadingChart(true);
      setError(null);
      const [seriesRes, opsRes] = await Promise.all([
        api.getDailyOperatingSeries({ from, to }) as Promise<{
          data?: {
            date: string;
            percent: number;
            amount_usd: number;
          }[];
        } | null>,
        api.getStrategyOperations({
          from,
          to,
          per_page: 200,
        }) as Promise<{
          data?: { resultLabel?: string | null }[];
        } | null>,
      ]);
      setChartSeries(
        (seriesRes?.data ?? []).map((row) => ({
          date: row.date,
          percent: row.percent,
          amountUsd: row.amount_usd,
        })),
      );
      setResultCounts(countStrategyResults(opsRes?.data ?? []));
    } catch (e: unknown) {
      setChartSeries([]);
      setResultCounts({ positive: 0, negative: 0, bePlus: 0, beMinus: 0 });
      setError(
        e instanceof Error ? e.message : "Error al cargar evolución diaria",
      );
    } finally {
      setLoadingChart(false);
    }
  };

  const handleExport = async () => {
    if (!exportFrom || !exportTo) {
      setError("Completá desde y hasta para exportar.");
      return;
    }
    if (exportFrom > exportTo) {
      setError("La fecha desde no puede ser posterior a la fecha hasta.");
      return;
    }
    try {
      setExporting(true);
      setError(null);
      const res = (await api.getDailyOperatingSeries({
        from: exportFrom,
        to: exportTo,
      })) as {
        data?: {
          date: string;
          percent: number;
          amount_usd: number;
          notes?: string | null;
        }[];
      } | null;
      const rows = res?.data ?? [];
      if (rows.length === 0) {
        setError("No hay operativas en el período seleccionado.");
        return;
      }
      exportOperatingToExcel(rows, `${exportFrom}_${exportTo}`);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Error al exportar Excel");
    } finally {
      setExporting(false);
    }
  };

  const goMonthlyOlder = () => {
    const next = monthlyOffset + monthsWindow;
    setMonthlyOffset(next);
    void loadMonthly(next);
  };

  const goMonthlyNewer = () => {
    const next = Math.max(0, monthlyOffset - monthsWindow);
    setMonthlyOffset(next);
    void loadMonthly(next);
  };

  const changeMonthsWindow = (months: number) => {
    setMonthsWindow(months);
    setMonthlyOffset(0);
    void loadMonthly(0, months);
  };

  useEffect(() => {
    void loadHistory(1);
    void loadMonthly(0);
    void loadChartRange();
  }, []);

  const cards = useMemo(() => {
    return monthlySummary;
  }, [monthlySummary]);

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-t-primary">
            Historial de Operativas
          </h1>
          <p className="mt-1 text-sm text-t-muted">
            Resumen mensual + detalle diario (paginado).
          </p>
        </div>
        <div className="flex flex-col items-stretch gap-2 sm:items-end">
          <div className="flex flex-wrap items-end gap-2">
            <div>
              <label
                className="mb-1 block text-xs text-t-dim"
                htmlFor="export-from"
              >
                Desde
              </label>
              <DatePicker
                id="export-from"
                value={exportFrom}
                onChange={setExportFrom}
              />
            </div>
            <div>
              <label
                className="mb-1 block text-xs text-t-dim"
                htmlFor="export-to"
              >
                Hasta
              </label>
              <DatePicker
                id="export-to"
                value={exportTo}
                onChange={setExportTo}
              />
            </div>
            <Button
              type="button"
              variant="outline"
              onClick={() => void handleExport()}
              disabled={exporting}
            >
              {exporting ? "Exportando..." : "Descargar Excel"}
            </Button>
          </div>
          <div className="flex flex-wrap gap-2 justify-end">
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                void loadHistory(historyPage);
                void loadMonthly(monthlyOffset);
                void loadChartRange();
              }}
              disabled={loadingHistory || loadingMonthly || loadingChart}
            >
              Actualizar
            </Button>
          </div>
        </div>
      </div>

      {error ? (
        <div className="rounded-lg border border-b-default bg-error/15 px-4 py-3 text-sm text-error">
          {error}
        </div>
      ) : null}

      <div className="admin-card p-6 space-y-4">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h2 className="text-xl font-bold text-t-primary">
              Rendimiento por mes
            </h2>
            <p className="mt-1 text-sm text-t-muted">
              Resultado compuesto en % y USD por mes.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <label className="text-sm text-t-muted" htmlFor="months-window">
              Período:
            </label>
            <select
              id="months-window"
              value={monthsWindow}
              onChange={(e) => changeMonthsWindow(Number(e.target.value))}
              className="rounded-lg border border-b-default bg-dark-card px-3 py-2 text-sm text-t-primary"
            >
              {MONTH_WINDOW_OPTIONS.map((months) => (
                <option key={months} value={months}>
                  {months} {months === 1 ? "mes" : "meses"}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="flex items-center justify-between gap-3">
          <button
            type="button"
            onClick={goMonthlyOlder}
            disabled={loadingMonthly || !monthlySummary.some((m) => m.days > 0)}
            className="rounded-lg border border-b-default bg-dark-card px-3 py-1.5 text-sm font-medium text-t-muted hover:bg-dark-section disabled:cursor-not-allowed disabled:opacity-40"
            title="Meses anteriores"
          >
            &lsaquo;
          </button>

          <div className="flex-1 text-center">
            <div className="text-xs text-t-dim mt-0.5">
              {monthlySummary.length > 0 ? (
                <>
                  {monthLabel(monthlySummary[monthlySummary.length - 1].month)}
                  {" – "}
                  {monthLabel(monthlySummary[0].month)}
                </>
              ) : null}
            </div>
          </div>

          <button
            type="button"
            onClick={goMonthlyNewer}
            disabled={loadingMonthly || monthlyOffset === 0}
            className="rounded-lg border border-b-default bg-dark-card px-3 py-1.5 text-sm font-medium text-t-muted hover:bg-dark-section disabled:cursor-not-allowed disabled:opacity-40"
            title="Meses siguientes"
          >
            &rsaquo;
          </button>
        </div>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {loadingMonthly && cards.length === 0 ? (
            <div className="text-sm text-t-dim">Cargando…</div>
          ) : null}

          {cards.map((m) => {
            const v = m.compounded_percent;
            const tone =
              v > 0
                ? "text-success bg-success/15 border-b-default"
                : v < 0
                  ? "text-error bg-error/15 border-b-default"
                  : "text-t-muted bg-dark-section border-b-default";
            const sign = v > 0 ? "+" : "";
            return (
              <div key={m.month} className={`rounded-lg border p-4 ${tone}`}>
                <div>
                  <div className="text-xs uppercase">{monthLabel(m.month)}</div>
                  <div className="mt-1 text-lg font-semibold">
                    {sign}
                    {formatNumberAR(v)}%
                  </div>
                  <div className="mt-1 flex items-center gap-2 text-sm font-medium">
                    <span>
                      {hideUsdAmounts
                        ? USD_MASK
                        : formatCurrencyAR(m.total_usd ?? 0)}
                    </span>
                    <button
                      type="button"
                      className="rounded-md border border-black/10 bg-dark-card/60 p-1 text-sm hover:bg-primary-dim"
                      onClick={toggleHideUsdAmounts}
                      title={
                        hideUsdAmounts
                          ? "Mostrar importes USD"
                          : "Ocultar importes USD"
                      }
                      aria-label={
                        hideUsdAmounts
                          ? "Mostrar importes USD"
                          : "Ocultar importes USD"
                      }
                      aria-pressed={hideUsdAmounts}
                    >
                      {hideUsdAmounts ? (
                        <EyeOffIcon className="h-4 w-4" />
                      ) : (
                        <EyeIcon className="h-4 w-4" />
                      )}
                    </button>
                  </div>
                  <div className="mt-1 text-xs opacity-80">
                    Días cargados: {m.days}
                  </div>
                </div>
              </div>
            );
          })}

          {!loadingMonthly && cards.length === 0 ? (
            <div className="text-sm text-t-dim">
              No hay operativas para resumir.
            </div>
          ) : null}
        </div>
      </div>

      <div className="admin-card p-6 space-y-4">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h2 className="text-xl font-bold text-t-primary">
              Evolución diaria
            </h2>
            <p className="mt-1 text-sm text-t-muted">
              Resultado en USD y conteo de resultados de operaciones para el
              período seleccionado.
            </p>
          </div>
          <div className="flex flex-wrap items-end gap-2">
            <div>
              <label
                className="mb-1 block text-xs text-t-dim"
                htmlFor="chart-from"
              >
                Desde
              </label>
              <DatePicker
                id="chart-from"
                value={chartFrom}
                onChange={setChartFrom}
              />
            </div>
            <div>
              <label
                className="mb-1 block text-xs text-t-dim"
                htmlFor="chart-to"
              >
                Hasta
              </label>
              <DatePicker id="chart-to" value={chartTo} onChange={setChartTo} />
            </div>
            <Button
              type="button"
              variant="outline"
              onClick={() => void loadChartRange()}
              disabled={loadingChart}
            >
              {loadingChart ? "Cargando..." : "Aplicar"}
            </Button>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="rounded-lg border border-b-default bg-dark-section px-3 py-3">
            <p className="text-xs uppercase tracking-wide text-t-dim">
              Positivos
            </p>
            <p className="mt-1 text-xl font-semibold text-success">
              {resultCounts.positive}
            </p>
          </div>
          <div className="rounded-lg border border-b-default bg-dark-section px-3 py-3">
            <p className="text-xs uppercase tracking-wide text-t-dim">
              Negativos
            </p>
            <p className="mt-1 text-xl font-semibold text-error">
              {resultCounts.negative}
            </p>
          </div>
          <div className="rounded-lg border border-b-default bg-dark-section px-3 py-3">
            <p className="text-xs uppercase tracking-wide text-t-dim">BE+</p>
            <p className="mt-1 text-xl font-semibold text-t-dim">
              {resultCounts.bePlus}
            </p>
          </div>
          <div className="rounded-lg border border-b-default bg-dark-section px-3 py-3">
            <p className="text-xs uppercase tracking-wide text-t-dim">BE-</p>
            <p className="mt-1 text-xl font-semibold text-t-dim">
              {resultCounts.beMinus}
            </p>
          </div>
        </div>

        <OperatingDualChart
          series={chartSeries}
          hideUsdAmounts={hideUsdAmounts}
        />
      </div>

      <div className="admin-card p-6 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-t-primary">Detalle diario</h2>
          <div className="text-xs text-t-dim">
            {historyMeta ? (
              <>
                Página {historyMeta.page} de {historyMeta.total_pages} • Total:{" "}
                {historyMeta.total}
              </>
            ) : null}
          </div>
        </div>

        <div className="overflow-x-auto rounded-xl border border-b-default">
          <table className="min-w-full divide-y divide-b-default">
            <thead className="bg-dark-section">
              <tr>
                <th className="px-3 py-3 text-left text-xs font-medium uppercase tracking-wider text-t-muted sm:px-4">
                  Fecha
                </th>
                <th className="hidden px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-t-muted sm:table-cell">
                  Operación
                </th>
                <th className="px-3 py-3 text-right text-xs font-medium uppercase tracking-wider text-t-muted sm:px-4">
                  Resultado
                </th>
                <th className="hidden px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-t-muted sm:table-cell">
                  Foto
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-b-default bg-dark-card">
              {history.length === 0 ? (
                <tr>
                  <td
                    className="px-4 py-6 text-center text-sm text-t-dim"
                    colSpan={4}
                  >
                    {loadingHistory
                      ? "Cargando…"
                      : "No hay operativas cargadas."}
                  </td>
                </tr>
              ) : (
                history.map((h) => {
                  const dayOperations = operationsByDate[h.date] ?? [];
                  const operation =
                    dayOperations.length > 0 ? (
                      <div className="space-y-1.5">
                        {dayOperations.map((op) => (
                          <OperatingAsset
                            key={op.id}
                            asset={op.asset}
                            direction={op.direction}
                            compact
                          />
                        ))}
                      </div>
                    ) : (
                      <span className="text-sm text-t-dim">—</span>
                    );
                  const photo =
                    (captureCounts[h.date] || 0) > 0 ? (
                      <button
                        type="button"
                        className="inline-flex items-center justify-center rounded-md border border-b-accent bg-primary-dim p-1.5 text-primary hover:bg-primary/20 disabled:opacity-50"
                        onClick={() => void openDayCaptures(h.date)}
                        disabled={loadingCaptures}
                        title={`Ver ${captureCounts[h.date]} captura(s)`}
                        aria-label={`Ver capturas del ${h.date}`}
                      >
                        <CameraIcon className="h-4 w-4" />
                      </button>
                    ) : null;

                  return (
                    <tr key={h.id} className="hover:bg-dark-section">
                      <td className="px-3 py-3 text-sm text-t-primary sm:px-4">
                        <div className="flex items-center gap-2 whitespace-nowrap">
                          {formatDateAR(h.date, { time: false })}
                          {/* En el celular, la foto va al lado de la fecha. */}
                          <span className="sm:hidden">{photo}</span>
                        </div>
                        {/* En el celular, la operación va debajo de la fecha. */}
                        <div className="mt-1.5 sm:hidden">{operation}</div>
                      </td>
                      <td className="hidden px-4 py-3 sm:table-cell">
                        {operation}
                      </td>
                      <td className="whitespace-nowrap px-3 py-3 text-right tabular-nums sm:px-4">
                        <div
                          className={`text-sm font-semibold ${
                            hideUsdAmounts
                              ? "text-t-muted"
                              : resultTone(Number(h.amount_usd ?? 0))
                          }`}
                        >
                          {hideUsdAmounts
                            ? USD_MASK
                            : signedUsd(Number(h.amount_usd ?? 0))}
                        </div>
                        <div
                          className={`mt-0.5 text-xs ${resultTone(Number(h.percent))}`}
                        >
                          {signedPercent(Number(h.percent))}
                        </div>
                      </td>
                      <td className="hidden px-4 py-3 text-center sm:table-cell">
                        {photo ?? <span className="text-xs text-t-dim">—</span>}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        <div className="flex items-center justify-end gap-2">
          <Button
            type="button"
            variant="outline"
            disabled={loadingHistory || !historyMeta || historyMeta.page <= 1}
            onClick={() => void loadHistory((historyMeta?.page || 1) - 1)}
          >
            Anterior
          </Button>
          <Button
            type="button"
            variant="outline"
            disabled={
              loadingHistory ||
              !historyMeta ||
              historyMeta.page >= historyMeta.total_pages
            }
            onClick={() => void loadHistory((historyMeta?.page || 1) + 1)}
          >
            Siguiente
          </Button>
        </div>
      </div>

      <DayCaptureCarousel
        open={carouselOpen}
        date={carouselDate || ""}
        captures={carouselCaptures}
        onClose={() => {
          setCarouselOpen(false);
          setCarouselDate(null);
          setCarouselCaptures([]);
        }}
      />
    </div>
  );
};
