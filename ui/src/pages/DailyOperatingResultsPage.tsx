import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';
import { formatNumberAR } from '../lib/formatters';
import { DatePicker } from '../components/ui/DatePicker';

type PreviewRow = {
  investor_id: string;
  investor_name: string;
  investor_email: string;
  balance_before: number;
  delta: number;
  balance_after: number;
};

type PreviewData = {
  date: string;
  percent: number;
  investors_count: number;
  total_before: number;
  total_delta: number;
  total_after: number;
  investors: PreviewRow[];
};

const todayISO = () => {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};

export const DailyOperatingResultsPage = () => {
  const [date, setDate] = useState(todayISO());
  const [percent, setPercent] = useState<string>('0,00');
  const [notes, setNotes] = useState<string>('');
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [applying, setApplying] = useState(false);
  const [notice, setNotice] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const [alertOpen, setAlertOpen] = useState(false);
  const [alertTitle, setAlertTitle] = useState<string>('');
  const [alertMessage, setAlertMessage] = useState<string>('');

  type HistoryRow = { id: string; date: string; percent: number; applied_by: { name: string | null } };
  type HistoryMeta = { page: number; per_page: number; total: number; total_pages: number };
  const [historyRows, setHistoryRows] = useState<HistoryRow[]>([]);
  const [historyMeta, setHistoryMeta] = useState<HistoryMeta | null>(null);
  const [historyPage, setHistoryPage] = useState(1);
  const [loadingHistory, setLoadingHistory] = useState(true);

  const loadHistory = useCallback((p: number) => {
    setLoadingHistory(true);
    api
      .getDailyOperatingResults({ page: p, per_page: 20 })
      .then((res: { data?: HistoryRow[]; meta?: HistoryMeta } | null) => {
        setHistoryRows(res?.data ?? []);
        setHistoryMeta(res?.meta ?? null);
      })
      .catch(() => {})
      .finally(() => setLoadingHistory(false));
  }, []);

  useEffect(() => { loadHistory(historyPage); }, [historyPage, loadHistory]);

  const parsedPercent = useMemo(() => {
    const cleaned = percent.replace(/%/g, '').trim();
    if (!cleaned) return null;
    const normalized = cleaned.replace(/\./g, '').replace(/,/g, '.');
    const n = Number(normalized);
    return Number.isFinite(n) ? n : null;
  }, [percent]);

  const showAlert = (title: string, message: string) => {
    setAlertTitle(title);
    setAlertMessage(message);
    setAlertOpen(true);
  };

  const extractErrorMessage = (e: unknown, fallback: string) => {
    const raw = (e instanceof Error ? e.message : null) ?? fallback;
    try {
      const parsed = JSON.parse(raw);
      if (parsed?.error) return String(parsed.error);
    } catch {
      // ignore
    }
    return String(raw);
  };

  const isValidISODate = (v: string) => /^\d{4}-\d{2}-\d{2}$/.test(v);
  const isFutureDate = (v: string) => v > todayISO();

  const runPreview = async () => {
    if (!date || !isValidISODate(date)) {
      showAlert('Fecha inválida', 'Usá el selector de fecha (formato YYYY-MM-DD).');
      return;
    }
    if (isFutureDate(date)) {
      showAlert('Fecha inválida', 'No se puede cargar operativa diaria con fecha futura.');
      return;
    }
    if (parsedPercent === null) {
      showAlert('Porcentaje inválido', 'Ingresá un porcentaje válido (ej: 0,10).');
      return;
    }

    try {
      setLoadingPreview(true);
      setNotice(null);
      const res = await api.previewDailyOperatingResult({ date, percent: parsedPercent, notes: notes || undefined });
      setPreview(res?.data as PreviewData);
    } catch (e: unknown) {
      setPreview(null);
      showAlert('No se pudo previsualizar', extractErrorMessage(e, 'Error al previsualizar'));
    } finally {
      setLoadingPreview(false);
    }
  };

  const apply = async () => {
    if (!preview) return;
    if (parsedPercent === null) return;
    if (preview.investors_count <= 0) {
      showAlert('Sin impacto', 'No hay inversores activos con capital para esa fecha. No se puede aplicar.');
      return;
    }

    try {
      setApplying(true);
      await api.createDailyOperatingResult({ date, percent: parsedPercent, notes: notes || undefined });
      setNotice({ type: 'success', message: 'Operativa diaria aplicada.' });
      setConfirmOpen(false);
      setPreview(null);
      setHistoryPage(1);
      loadHistory(1);
    } catch (e: unknown) {
      showAlert('No se pudo aplicar', extractErrorMessage(e, 'Error al aplicar'));
    } finally {
      setApplying(false);
    }
  };

  const rows = useMemo(() => {
    if (!preview?.investors) return [];
    return [...preview.investors].sort((a, b) => (a.investor_name < b.investor_name ? -1 : 1));
  }, [preview]);
  const canApplyPreview = !!preview && preview.investors_count > 0;

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Operativa diaria</h1>
          <p className="mt-1 text-sm text-gray-600">
            Cargá el resultado operativo del día (porcentaje). Se aplica a todos los inversores activos con capital.
          </p>
        </div>
      </div>

      {notice ? (
        <div
          className={
            `rounded-lg border px-4 py-3 text-sm ` +
            (notice.type === 'success'
              ? 'border-green-200 bg-green-50 text-green-800'
              : 'border-red-200 bg-red-50 text-red-800')
          }
        >
          {notice.message}
        </div>
      ) : null}

      <div className="rounded-lg bg-white p-6 shadow space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700">Fecha</label>
            <DatePicker value={date} onChange={setDate} />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700">Resultado (%)</label>
            <Input
              type="text"
              value={percent}
              onChange={(e) => setPercent(e.target.value)}
              placeholder="Ej: 0,10"
            />
            <p className="text-xs text-gray-500">Se redondea a 2 decimales en el impacto por inversor.</p>
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700">Notas (opcional)</label>
            <Input type="text" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="" />
          </div>
        </div>

        <div className="flex gap-3 justify-end">
          <Button type="button" variant="outline" onClick={() => { setPreview(null); }}>
            Limpiar
          </Button>
          <Button type="button" onClick={() => void runPreview()} disabled={loadingPreview}>
            {loadingPreview ? 'Previsualizando…' : 'Previsualizar'}
          </Button>
        </div>
      </div>

{preview ? (
        <div className="rounded-lg bg-white p-6 shadow space-y-4">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h2 className="text-xl font-bold text-gray-900">Preview</h2>
              <p className="mt-1 text-sm text-gray-600">
                Saldos calculados al cierre del <span className="font-semibold">{preview.date}</span> (18:00 GMT-3, antes de aplicar la operativa).
                Si hubo movimientos posteriores (depósitos/retiros/trading fees), puede diferir del balance actual.
              </p>
              <p className="mt-1 text-sm text-gray-600">
                Inversores impactados: <span className="font-semibold">{preview.investors_count}</span>
              </p>
            </div>
            <Button type="button" onClick={() => setConfirmOpen(true)} disabled={!canApplyPreview}>
              Aplicar
            </Button>
          </div>

          {!canApplyPreview ? (
            <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
              No hay inversores activos con capital para esa fecha. No es posible aplicar la operativa.
            </div>
          ) : null}

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="rounded-lg border border-gray-200 bg-gray-50 p-4">
              <div className="text-xs uppercase text-gray-500">Total antes (cierre)</div>
              <div className="mt-1 text-lg font-semibold text-gray-900">USD {formatNumberAR(preview.total_before)}</div>
            </div>
            <div className="rounded-lg border border-gray-200 bg-gray-50 p-4">
              <div className="text-xs uppercase text-gray-500">Delta total</div>
              <div className="mt-1 text-lg font-semibold text-gray-900">USD {formatNumberAR(preview.total_delta)}</div>
            </div>
            <div className="rounded-lg border border-gray-200 bg-gray-50 p-4">
              <div className="text-xs uppercase text-gray-500">Total después (cierre)</div>
              <div className="mt-1 text-lg font-semibold text-gray-900">USD {formatNumberAR(preview.total_after)}</div>
            </div>
          </div>

          <div className="overflow-hidden rounded-xl border border-gray-200">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Inversor</th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Antes (cierre)</th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Delta</th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Después (cierre)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 bg-white">
                {rows.map((r) => (
                  <tr key={r.investor_id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm text-gray-900">
                      <div className="font-medium">{r.investor_name}</div>
                      <div className="text-xs text-gray-500">{r.investor_email}</div>
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-gray-900">USD {formatNumberAR(r.balance_before)}</td>
                    <td className="px-4 py-3 text-right text-sm text-gray-900">USD {formatNumberAR(r.delta)}</td>
                    <td className="px-4 py-3 text-right text-sm text-gray-900">USD {formatNumberAR(r.balance_after)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : null}

      {/* Recent history */}
      <div>
        <h2 className="mb-3 text-lg font-semibold text-gray-900">Últimas operativas aplicadas</h2>

        {loadingHistory ? (
          <div className="py-6 text-center text-sm text-gray-500">Cargando...</div>
        ) : historyRows.length === 0 ? (
          <div className="py-6 text-center text-sm text-gray-500">No hay operativas registradas.</div>
        ) : (
          <>
            <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">Fecha</th>
                    <th className="px-5 py-3 text-right text-xs font-semibold uppercase tracking-wider text-gray-600">Rendimiento</th>
                    <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">Aplicado por</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 bg-white">
                  {historyRows.map((row) => {
                    const d = new Date(row.date);
                    const dateStr = d.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' });
                    const isPos = row.percent >= 0;
                    return (
                      <tr key={row.id} className="hover:bg-gray-50">
                        <td className="px-5 py-3 text-sm text-gray-700">{dateStr}</td>
                        <td className={`px-5 py-3 text-right text-sm font-semibold ${isPos ? 'text-green-700' : 'text-red-700'}`}>
                          {isPos ? '+' : ''}{row.percent.toFixed(2).replace('.', ',')}%
                        </td>
                        <td className="px-5 py-3 text-sm text-gray-500">{row.applied_by?.name ?? '—'}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {historyMeta && historyMeta.total_pages > 1 ? (
              <div className="mt-4 flex items-center justify-between">
                <span className="text-sm text-gray-600">
                  Página <span className="font-semibold">{historyMeta.page}</span> de{' '}
                  <span className="font-semibold">{historyMeta.total_pages}</span>
                  {' · '}<span className="text-gray-500">{historyMeta.total} registros</span>
                </span>
                <div className="flex gap-2">
                  <button
                    type="button"
                    disabled={historyPage <= 1}
                    onClick={() => setHistoryPage((p) => p - 1)}
                    className="rounded border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                  >
                    Anterior
                  </button>
                  <button
                    type="button"
                    disabled={historyPage >= historyMeta.total_pages}
                    onClick={() => setHistoryPage((p) => p + 1)}
                    className="rounded border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                  >
                    Siguiente
                  </button>
                </div>
              </div>
            ) : null}
          </>
        )}
      </div>

{alertOpen ? (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div
            className="fixed inset-0 bg-black/15 transition-opacity"
            onClick={() => setAlertOpen(false)}
          />
          <div className="flex min-h-full items-center justify-center p-4">
            <div className="relative w-full max-w-md overflow-hidden rounded-lg bg-white shadow-xl">
              <div className="border-b border-gray-200 px-6 py-4">
                <h3 className="text-lg font-semibold text-gray-900">{alertTitle || 'Error'}</h3>
              </div>
              <div className="px-6 py-4">
                <p className="text-sm text-gray-700 whitespace-pre-wrap">{alertMessage}</p>
              </div>
              <div className="flex justify-end gap-3 border-t border-gray-200 px-6 py-4">
                <button
                  onClick={() => setAlertOpen(false)}
                  className="rounded-lg bg-[#58b098] px-4 py-2 text-sm font-medium text-white hover:bg-[#4aa48d] focus:outline-none focus:ring-2 focus:ring-[#58b098] focus:ring-offset-2"
                >
                  OK
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
      <ConfirmDialog
        isOpen={confirmOpen}
        title="Aplicar operativa diaria"
        message="Esta acción impactará en el capital actual de todos los inversores activos con capital. No se puede editar luego."
        confirmText={applying ? 'Aplicando…' : 'Confirmar y aplicar'}
        cancelText="Cancelar"
        confirmVariant="primary"
        onConfirm={() => void apply()}
        onClose={() => setConfirmOpen(false)}
      />
    </div>
  );
};
