import { useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { formatNumberAR } from '../lib/formatters';

type HistoryRow = {
  id: string;
  date: string;
  percent: number;
  notes?: string | null;
  created_at: string;
};

type MonthlySummaryRow = {
  month: string; // YYYY-MM
  days: number;
  compounded_percent: number;
  first_date: string;
  last_date: string;
};

const EyeIcon = ({ className }: { className?: string }) => (
  <svg
    className={className || ''}
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

const monthLabel = (ym: string) => {
  const m = String(ym || '').match(/^(\d{4})-(\d{2})$/);
  if (!m) return ym;
  const yyyy = m[1];
  const mm = Number(m[2]);
  const names = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  return `${names[mm - 1] || m[2]} ${yyyy}`;
};

export const OperatingHistoryPage = () => {
  const [history, setHistory] = useState<HistoryRow[]>([]);
  const [historyMeta, setHistoryMeta] = useState<{ page: number; per_page: number; total: number; total_pages: number } | null>(null);
  const [historyPage, setHistoryPage] = useState(1);
  const historyPerPage = 10;

  const [monthlySummary, setMonthlySummary] = useState<MonthlySummaryRow[]>([]);
  const [loadingHistory, setLoadingHistory] = useState(false);
  const [loadingMonthly, setLoadingMonthly] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [detailOpen, setDetailOpen] = useState(false);
  const [detailMonth, setDetailMonth] = useState<string | null>(null);
  const [detailRows, setDetailRows] = useState<{ id: string; date: string; percent: number; notes?: string | null }[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);


  const loadHistory = async (page: number) => {
    try {
      setLoadingHistory(true);
      setError(null);
      const res: any = await api.getDailyOperatingResults({ page, per_page: historyPerPage });
      setHistory((res?.data || []) as HistoryRow[]);
      setHistoryMeta((res?.meta || null) as any);
      setHistoryPage(page);
    } catch (e: any) {
      setError(e?.message || 'Error al cargar historial');
    } finally {
      setLoadingHistory(false);
    }
  };

  const loadMonthly = async () => {
    try {
      setLoadingMonthly(true);
      const res: any = await api.getDailyOperatingMonthlySummary({ months: 12 });
      setMonthlySummary((res?.data || []) as MonthlySummaryRow[]);
    } catch {
      // ignore
    } finally {
      setLoadingMonthly(false);
    }
  };

  
  const openMonthDetail = async (month: string) => {
    try {
      setDetailOpen(true);
      setDetailMonth(month);
      setDetailRows([]);
      setDetailLoading(true);
      const res: any = await api.getDailyOperatingByMonth({ month });
      setDetailRows((res?.data || []) as any);
    } catch (e: any) {
      setError(e?.message || 'Error al cargar detalle del mes');
    } finally {
      setDetailLoading(false);
    }
  };

useEffect(() => {
    void loadHistory(1);
    void loadMonthly();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const cards = useMemo(() => {
    return monthlySummary;
  }, [monthlySummary]);

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Historial de Operativas</h1>
          <p className="mt-1 text-sm text-gray-600">Resumen mensual + detalle diario (paginado).</p>
        </div>
        <Button type="button" variant="outline" onClick={() => { void loadHistory(historyPage); void loadMonthly(); }} disabled={loadingHistory || loadingMonthly}>
          Actualizar
        </Button>
      </div>

      {error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>
      ) : null}

      <div className="rounded-lg bg-white p-6 shadow space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900">Resumen por mes</h2>
          <div className="text-xs text-gray-500">Últimos 12 meses</div>
        </div>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {(loadingMonthly && cards.length === 0) ? (
            <div className="text-sm text-gray-500">Cargando…</div>
          ) : null}

          {cards.map((m) => {
            const v = m.compounded_percent;
            const tone = v > 0 ? 'text-green-700 bg-green-50 border-green-200' : (v < 0 ? 'text-red-700 bg-red-50 border-red-200' : 'text-gray-700 bg-gray-50 border-gray-200');
            const sign = v > 0 ? '+' : '';
            return (
              <div key={m.month} className={`rounded-lg border p-4 ${tone}`}>
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="text-xs uppercase">{monthLabel(m.month)}</div>
                    <div className="mt-1 text-lg font-semibold">{sign}{formatNumberAR(v)}%</div>
                    <div className="mt-1 text-xs opacity-80">Días cargados: {m.days}</div>
                  </div>
                  <button
                    type="button"
                    className="rounded-md border border-black/10 bg-white/60 px-2 py-1 text-sm hover:bg-white"
                    onClick={() => void openMonthDetail(m.month)}
                    title="Ver"
                    aria-label="Ver detalle"
                  >
                    <EyeIcon className="h-4 w-4" />
                  </button>
                </div>
              </div>
            );
          })}

          {(!loadingMonthly && cards.length === 0) ? (
            <div className="text-sm text-gray-500">No hay operativas para resumir.</div>
          ) : null}
        </div>
      </div>

      <div className="rounded-lg bg-white p-6 shadow space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900">Detalle diario</h2>
          <div className="text-xs text-gray-500">
            {historyMeta ? <>Página {historyMeta.page} de {historyMeta.total_pages} • Total: {historyMeta.total}</> : null}
          </div>
        </div>

        <div className="overflow-hidden rounded-xl border border-gray-200">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Fecha</th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Resultado (%)</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Notas</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 bg-white">
              {history.length === 0 ? (
                <tr>
                  <td className="px-4 py-6 text-center text-sm text-gray-500" colSpan={3}>
                    {loadingHistory ? 'Cargando…' : 'No hay operativas cargadas.'}
                  </td>
                </tr>
              ) : (
                history.map((h) => (
                  <tr key={h.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm text-gray-900">{h.date}</td>
                    <td className="px-4 py-3 text-right text-sm text-gray-900">{formatNumberAR(h.percent)}%</td>
                    <td className="px-4 py-3 text-sm text-gray-700">{h.notes || '—'}</td>
                  </tr>
                ))
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
            disabled={loadingHistory || !historyMeta || historyMeta.page >= historyMeta.total_pages}
            onClick={() => void loadHistory((historyMeta?.page || 1) + 1)}
          >
            Siguiente
          </Button>
        </div>
      </div>


      {detailOpen ? (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div
            className="fixed inset-0 bg-black bg-opacity-30 backdrop-blur-sm transition-opacity"
            onClick={() => setDetailOpen(false)}
          />
          <div className="flex min-h-full items-center justify-center p-4">
            <div className="relative w-full max-w-lg overflow-hidden rounded-lg bg-white shadow-xl">
              <div className="border-b border-gray-200 px-6 py-4">
                <h3 className="text-lg font-semibold text-gray-900">Detalle del mes</h3>
                <p className="mt-1 text-sm text-gray-600">{detailMonth ? monthLabel(detailMonth) : ''}</p>
              </div>
              <div className="px-6 py-4">
                {detailLoading ? (
                  <div className="text-sm text-gray-600">Cargando…</div>
                ) : (
                  <div className="overflow-hidden rounded-xl border border-gray-200">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Fecha</th>
                          <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Resultado (%)</th>
                          <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Notas</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-200 bg-white">
                        {detailRows.length === 0 ? (
                          <tr>
                            <td className="px-4 py-6 text-center text-sm text-gray-500" colSpan={3}>
                              No hay operativas cargadas para este mes.
                            </td>
                          </tr>
                        ) : (
                          detailRows.map((r) => (
                            <tr key={r.id} className="hover:bg-gray-50">
                              <td className="px-4 py-3 text-sm text-gray-900">{r.date}</td>
                              <td className="px-4 py-3 text-right text-sm text-gray-900">{formatNumberAR(r.percent)}%</td>
                              <td className="px-4 py-3 text-sm text-gray-700">{r.notes || '—'}</td>
                            </tr>
                          ))
                        )}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
              <div className="flex justify-end gap-3 border-t border-gray-200 px-6 py-4">
                <Button type="button" variant="outline" onClick={() => setDetailOpen(false)}>
                  Cerrar
                </Button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
};
