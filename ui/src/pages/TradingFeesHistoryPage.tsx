import { useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { formatCurrencyAR } from '../lib/formatters';

type TradingFeeHistoryRow = {
  id: string;
  investor_id: string;
  investor_name: string;
  investor_email: string;
  applied_by_name: string;
  period_start: string;
  period_end: string;
  profit_amount: number;
  fee_percentage: number;
  fee_amount: number;
  source?: 'PERIODIC' | 'WITHDRAWAL';
  withdrawal_amount?: number | null;
  applied_at: string;
  voided_at?: string | null;
};

type Pagination = {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
};

type TradingFeesHistoryResponse = {
  data: TradingFeeHistoryRow[];
  pagination: Pagination;
};

const formatDate = (value: string | null | undefined) => {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);

  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = String(d.getFullYear());
  const hh = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${dd}/${mm}/${yyyy} ${hh}:${min}`;
};

const formatPeriod = (start: string, ending: string) => {
  const fmt = (v: string) => {
    const m = String(v || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!m) return v;
    return `${m[3]}/${m[2]}/${m[1]}`;
  };
  return `${fmt(start)} - ${fmt(ending)}`;
};

const feeLabel = (row: TradingFeeHistoryRow) =>
  row.source === 'WITHDRAWAL' ? 'Trading Fee por retiro' : 'Trading Fee';

export const TradingFeesHistoryPage = () => {
  const [rows, setRows] = useState<TradingFeeHistoryRow[]>([]);
  const [pagination, setPagination] = useState<Pagination>({ page: 1, per_page: 25, total: 0, total_pages: 0 });
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<'ALL' | 'ACTIVE' | 'VOIDED'>('ALL');

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        setError('');
        const response = (await api.getTradingFees({
          include_voided: true,
          page,
          per_page: 25,
        })) as TradingFeesHistoryResponse | TradingFeeHistoryRow[];

        if (Array.isArray(response)) {
          setRows(response);
          setPagination({
            page: 1,
            per_page: 25,
            total: response.length,
            total_pages: response.length > 0 ? 1 : 0,
          });
          return;
        }

        setRows(Array.isArray(response?.data) ? response.data : []);
        setPagination(
          response?.pagination || {
            page,
            per_page: 25,
            total: 0,
            total_pages: 0,
          },
        );
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : 'Error al cargar historial');
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [page]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return rows.filter((row) => {
      const matchesText =
        q.length === 0 ||
        String(row.investor_name || '')
          .toLowerCase()
          .includes(q) ||
        String(row.investor_email || '')
          .toLowerCase()
          .includes(q);

      const isVoided = !!row.voided_at;
      const matchesStatus = status === 'ALL' || (status === 'ACTIVE' && !isVoided) || (status === 'VOIDED' && isVoided);
      return matchesText && matchesStatus;
    });
  }, [rows, search, status]);

  if (loading) return <div className="p-6 text-gray-600">Cargando...</div>;
  if (error) return <div className="p-6 text-red-600">{error}</div>;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Historial de Trading Fees</h1>
        <p className="mt-1 text-sm text-gray-600">Histórico de comisiones cobradas por Winbit (incluye anuladas).</p>
      </div>

      <div className="rounded-lg bg-white p-4 shadow">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por inversor o email..."
            className="h-10 rounded border border-gray-300 bg-white px-3 text-sm"
          />
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value as 'ALL' | 'ACTIVE' | 'VOIDED')}
            className="h-10 rounded border border-gray-300 bg-white px-3 text-sm"
          >
            <option value="ALL">Todos</option>
            <option value="ACTIVE">Cobradas</option>
            <option value="VOIDED">Anuladas</option>
          </select>
          <div className="flex items-center text-sm text-gray-600">
            Resultados en página: {filtered.length} de {rows.length} (total: {pagination.total})
          </div>
        </div>
      </div>

      <div className="hidden md:block overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Fecha</th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Inversor</th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Tipo</th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Período / Retiro</th>
              <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Profit</th>
              <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">%</th>
              <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Fee cobrada</th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Aplicado por</th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Estado</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white">
            {filtered.map((row) => {
              const isVoided = !!row.voided_at;
              return (
                <tr key={row.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm text-gray-900">{formatDate(row.applied_at)}</td>
                  <td className="px-4 py-3 text-sm">
                    <div className="font-medium text-gray-900">{row.investor_name}</div>
                    <div className="text-xs text-gray-500">{row.investor_email}</div>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700">{feeLabel(row)}</td>
                  <td className="px-4 py-3 text-sm text-gray-700">
                    {row.source === 'WITHDRAWAL'
                      ? `Retiro: ${formatCurrencyAR(Number(row.withdrawal_amount || 0))}`
                      : formatPeriod(row.period_start, row.period_end)}
                  </td>
                  <td className="px-4 py-3 text-right text-sm text-gray-900">{formatCurrencyAR(row.profit_amount)}</td>
                  <td className="px-4 py-3 text-right text-sm text-gray-900">{row.fee_percentage}%</td>
                  <td className="px-4 py-3 text-right text-sm font-semibold text-purple-700">{formatCurrencyAR(row.fee_amount)}</td>
                  <td className="px-4 py-3 text-sm text-gray-700">{row.applied_by_name}</td>
                  <td className="px-4 py-3 text-sm">
                    {isVoided ? (
                      <span className="inline-flex rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-800">
                        Anulada ({formatDate(row.voided_at)})
                      </span>
                    ) : (
                      <span className="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-800">Cobrada</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="grid gap-3 md:hidden">
        {filtered.map((row) => {
          const isVoided = !!row.voided_at;
          return (
            <div key={row.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <div className="text-sm font-semibold text-gray-900">{row.investor_name}</div>
                  <div className="text-xs text-gray-500">{row.investor_email}</div>
                </div>
                {isVoided ? (
                  <span className="inline-flex rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-800">Anulada</span>
                ) : (
                  <span className="inline-flex rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-800">Cobrada</span>
                )}
              </div>
              <div className="mt-2 text-xs text-gray-600">Aplicada: {formatDate(row.applied_at)}</div>
              {isVoided ? <div className="text-xs text-red-600">Anulada: {formatDate(row.voided_at)}</div> : null}
              <div className="mt-2 text-sm text-gray-700">Tipo: {feeLabel(row)}</div>
              <div className="mt-1 text-sm text-gray-700">
                {row.source === 'WITHDRAWAL'
                  ? `Retiro: ${formatCurrencyAR(Number(row.withdrawal_amount || 0))}`
                  : `Período: ${formatPeriod(row.period_start, row.period_end)}`}
              </div>
              <div className="mt-1 text-sm text-gray-700">Profit: {formatCurrencyAR(row.profit_amount)}</div>
              <div className="mt-1 text-sm text-gray-700">Fee: {row.fee_percentage}% · {formatCurrencyAR(row.fee_amount)}</div>
              <div className="mt-1 text-xs text-gray-500">Aplicado por: {row.applied_by_name}</div>
            </div>
          );
        })}
      </div>

      <div className="flex items-center justify-end gap-2">
        <button
          type="button"
          onClick={() => setPage((prev) => Math.max(1, prev - 1))}
          disabled={pagination.page <= 1}
          className="rounded border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          Anterior
        </button>
        <div className="text-sm text-gray-600">
          Página {pagination.total_pages === 0 ? 0 : pagination.page} de {pagination.total_pages}
        </div>
        <button
          type="button"
          onClick={() => setPage((prev) => prev + 1)}
          disabled={pagination.total_pages === 0 || pagination.page >= pagination.total_pages}
          className="rounded border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          Siguiente
        </button>
      </div>
    </div>
  );
};
