import { useEffect, useState, useCallback } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { DatePicker } from '../components/ui/DatePicker';
import { formatCurrencyAR } from '../lib/formatters';

type Investor = { id: string; name: string; email: string };

type ReferralRow = {
  id: string;
  investor_id: string;
  investor_name: string;
  investor_email: string;
  amount: number;
  date: string;
};

type Pagination = { page: number; per_page: number; total: number; total_pages: number };

const formatDate = (iso: string) => {
  const d = new Date(iso);
  return d.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' });
};

export const ReferralCommissionsPage = () => {
  const [investors, setInvestors] = useState<Investor[]>([]);
  const [investorId, setInvestorId] = useState('');
  const [amount, setAmount] = useState('');
  const [appliedAt, setAppliedAt] = useState('');
  const [applying, setApplying] = useState(false);
  const [flash, setFlash] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  const [rows, setRows] = useState<ReferralRow[]>([]);
  const [pagination, setPagination] = useState<Pagination | null>(null);
  const [page, setPage] = useState(1);
  const [loadingHistory, setLoadingHistory] = useState(true);

  useEffect(() => {
    api
      .getAdminInvestors()
      .then((res: any) => {
        const list = Array.isArray(res?.data) ? res.data : [];
        setInvestors(list.map((inv: any) => ({ id: inv.id, name: inv.name, email: inv.email })));
      })
      .catch(() => {});
  }, []);

  const loadHistory = useCallback((p: number) => {
    setLoadingHistory(true);
    api
      .getReferralCommissions({ page: p })
      .then((res: any) => {
        setRows(res?.data ?? []);
        setPagination(res?.pagination ?? null);
      })
      .catch(() => {})
      .finally(() => setLoadingHistory(false));
  }, []);

  useEffect(() => {
    loadHistory(page);
  }, [page, loadHistory]);

  useEffect(() => {
    if (!flash) return;
    const t = setTimeout(() => setFlash(null), 4000);
    return () => clearTimeout(t);
  }, [flash]);

  const handleApply = async () => {
    if (!investorId) {
      setFlash({ type: 'error', message: 'Seleccioná un inversor' });
      return;
    }
    const num = Number(amount);
    if (!Number.isFinite(num) || num <= 0) {
      setFlash({ type: 'error', message: 'Ingresá un monto mayor a 0' });
      return;
    }

    try {
      setApplying(true);
      await api.applyReferralCommission(investorId, {
        amount: num,
        applied_at: appliedAt.trim() || undefined,
      });
      setFlash({ type: 'success', message: 'Comisión por referido aplicada correctamente' });
      setAmount('');
      setAppliedAt('');
      setInvestorId('');
      setPage(1);
      loadHistory(1);
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al aplicar comisión por referido' });
    } finally {
      setApplying(false);
    }
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Comisiones por referido</h1>
        <p className="mt-1 text-sm text-gray-600">
          Cargá un monto puntual al balance de un inversor. Si usás una fecha pasada, se recalcula el historial.
        </p>
      </div>

      {flash ? (
        <div
          className={
            `mb-4 rounded-lg border px-4 py-3 text-sm ` +
            (flash.type === 'success'
              ? 'border-green-200 bg-green-50 text-green-800'
              : 'border-red-200 bg-red-50 text-red-800')
          }
        >
          <div className="flex items-start justify-between gap-3">
            <span>{flash.message}</span>
            <button type="button" onClick={() => setFlash(null)} className="rounded px-2 py-1 text-xs hover:bg-black/5">
              Cerrar
            </button>
          </div>
        </div>
      ) : null}

      <div className="max-w-2xl rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label className="mb-1 block text-sm font-medium text-gray-700">Inversor</label>
            <Select
              portal
              value={investorId}
              onChange={setInvestorId}
              options={[
                { value: '', label: 'Seleccionar...' },
                ...investors.map((inv) => ({
                  value: inv.id,
                  label: `${inv.name} — ${inv.email}`,
                })),
              ]}
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Monto (USD)</label>
            <Input
              type="number"
              inputMode="decimal"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              onWheel={(e) => e.currentTarget.blur()}
              placeholder="Ej: 50"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Fecha (opcional)</label>
            <DatePicker value={appliedAt} onChange={setAppliedAt} />
          </div>
        </div>

        <div className="mt-5 flex justify-end">
          <Button onClick={() => void handleApply()} disabled={applying}>
            {applying ? 'Aplicando...' : 'Aplicar comisión'}
          </Button>
        </div>
      </div>

      {/* History */}
      <div className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-gray-900">Historial</h2>

        {loadingHistory ? (
          <div className="py-6 text-center text-sm text-gray-500">Cargando...</div>
        ) : rows.length === 0 ? (
          <div className="py-6 text-center text-sm text-gray-500">No hay comisiones por referido registradas.</div>
        ) : (
          <>
            <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">Inversor</th>
                    <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">Fecha</th>
                    <th className="px-5 py-3 text-right text-xs font-semibold uppercase tracking-wider text-gray-600">Monto</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 bg-white">
                  {rows.map((row) => (
                    <tr key={row.id} className="hover:bg-gray-50">
                      <td className="px-5 py-3">
                        <div className="text-sm font-medium text-gray-900">{row.investor_name}</div>
                        <div className="text-xs text-gray-500">{row.investor_email}</div>
                      </td>
                      <td className="px-5 py-3 text-sm text-gray-700">{formatDate(row.date)}</td>
                      <td className="px-5 py-3 text-right text-sm font-semibold text-green-700">
                        {formatCurrencyAR(row.amount)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {pagination && pagination.total_pages > 1 ? (
              <div className="mt-4 flex items-center justify-between">
                <span className="text-sm text-gray-600">
                  Página <span className="font-semibold">{pagination.page}</span> de{' '}
                  <span className="font-semibold">{pagination.total_pages}</span>
                  {' · '}
                  <span className="text-gray-500">{pagination.total} registros</span>
                </span>
                <div className="flex gap-2">
                  <button
                    type="button"
                    disabled={page <= 1}
                    onClick={() => setPage((p) => p - 1)}
                    className="rounded border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                  >
                    Anterior
                  </button>
                  <button
                    type="button"
                    disabled={page >= pagination.total_pages}
                    onClick={() => setPage((p) => p + 1)}
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
    </div>
  );
};
