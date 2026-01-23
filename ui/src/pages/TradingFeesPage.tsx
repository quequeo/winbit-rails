import { useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';

type InvestorSummary = {
  investor_id: string;
  investor_name: string;
  investor_email: string;
  current_balance: number;
  period_start: string;
  period_end: string;
  profit_amount: number;
  has_profit: boolean;
  already_applied?: boolean;
  applied_fee_amount?: number;
  applied_fee_percentage?: number;
  monthly_profits?: { month: string; amount: number }[];
};

type TradingFeeCalculation = {
  investor_id: string;
  investor_name: string;
  period_start: string;
  period_end: string;
  profit_amount: number;
  fee_percentage: number;
  fee_amount: number;
  current_balance: number;
  balance_after_fee: number;
};

export const TradingFeesPage = () => {
  const [investors, setInvestors] = useState<InvestorSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [percentages, setPercentages] = useState<Record<string, string>>({});
  const [confirmModal, setConfirmModal] = useState<TradingFeeCalculation | null>(null);
  const [applying, setApplying] = useState(false);
  const [notes, setNotes] = useState('');
  const [investorFilter, setInvestorFilter] = useState('');
  const [flash, setFlash] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const [detailModal, setDetailModal] = useState<InvestorSummary | null>(null);

  const computeQuarterStart = (d: Date) => {
    const y = d.getUTCFullYear();
    const m = d.getUTCMonth();
    const qStartMonth = Math.floor(m / 3) * 3;
    return new Date(Date.UTC(y, qStartMonth, 1));
  };

  const computeQuarterEnd = (quarterStart: Date) => {
    const y = quarterStart.getUTCFullYear();
    const m = quarterStart.getUTCMonth();
    // end = last day of month (m+2)
    return new Date(Date.UTC(y, m + 3, 0));
  };

  const computeLastCompletedQuarterEnd = () => {
    const now = new Date();
    const currentQStart = computeQuarterStart(now);
    return new Date(currentQStart.getTime() - 24 * 60 * 60 * 1000);
  };

  const formatYmd = (d: Date) => {
    const yyyy = String(d.getUTCFullYear());
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(d.getUTCDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  };

  type QuarterOption = { label: string; period_start: string; period_end: string; is_closed: boolean };

  const buildQuarterOptions = () => {
    const now = new Date();
    const lastClosedEnd = computeLastCompletedQuarterEnd();

    const opts: QuarterOption[] = [];

    // include current quarter first
    const currentStart = computeQuarterStart(now);
    const currentEnd = computeQuarterEnd(currentStart);
    opts.push({
      label: `Q${Math.floor(currentStart.getUTCMonth() / 3) + 1} ${currentStart.getUTCFullYear()} (${formatYmd(currentStart)} - ${formatYmd(currentEnd)})`,
      period_start: formatYmd(currentStart),
      period_end: formatYmd(currentEnd),
      is_closed: false,
    });

    // then include last N closed quarters
    let cursorEnd = lastClosedEnd;
    for (let i = 0; i < 8; i++) {
      const qStart = computeQuarterStart(cursorEnd);
      const qEnd = computeQuarterEnd(qStart);
      const q = Math.floor(qStart.getUTCMonth() / 3) + 1;
      opts.push({
        label: `Q${q} ${qStart.getUTCFullYear()} (${formatYmd(qStart)} - ${formatYmd(qEnd)})`,
        period_start: formatYmd(qStart),
        period_end: formatYmd(qEnd),
        is_closed: true,
      });
      cursorEnd = new Date(qStart.getTime() - 24 * 60 * 60 * 1000);
    }

    // de-dup by period
    const seen = new Set<string>();
    return opts.filter((o) => {
      const k = `${o.period_start}..${o.period_end}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
  };
  const quarterOptions = useMemo(() => buildQuarterOptions(), []);
  const [selectedQuarter, setSelectedQuarter] = useState(() => quarterOptions[0]);

  useEffect(() => {
    void loadInvestorsSummary(selectedQuarter?.period_start, selectedQuarter?.period_end);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedQuarter?.period_start, selectedQuarter?.period_end]);

  useEffect(() => {
    if (!flash) return;
    const t = setTimeout(() => setFlash(null), 4000);
    return () => clearTimeout(t);
  }, [flash]);

  const loadInvestorsSummary = async (period_start?: string, period_end?: string) => {
    try {
      setLoading(true);
      setError('');
      const response = (await api.getTradingFeesSummary({ period_start, period_end })) as InvestorSummary[];
      setInvestors(response);

      const initialPercentages: Record<string, string> = {};
      response.forEach((inv) => {
        const applied = typeof inv.applied_fee_percentage === 'number' ? inv.applied_fee_percentage : null;
        initialPercentages[inv.investor_id] = applied !== null ? String(applied) : '30';
      });
      setPercentages(initialPercentages);
    } catch (err: any) {
      setError(err.message || 'Error al cargar inversores');
    } finally {
      setLoading(false);
    }
  };

  const handlePercentageChange = (investorId: string, value: string) => {
    setPercentages((prev) => ({ ...prev, [investorId]: value }));
  };

  const formatCurrency = (amount: number) => {
    const num = Math.abs(amount);
    const formatted = num.toFixed(2);
    const parts = formatted.split('.');
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    const result = `$${parts[0]},${parts[1]}`;
    return amount < 0 ? `-${result}` : result;
  };

  const formatMonthLabel = (month: string) => {
    // month: YYYY-MM
    const m = String(month || '').match(/^(\d{4})-(\d{2})$/);
    if (!m) return month;
    const year = m[1];
    const mm = parseInt(m[2], 10);
    const names = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    const name = names[mm - 1] || m[2];
    return `${name} ${year}`;
  };

  const formatQuarterLabel = (periodStart: string) => {
    const s = String(periodStart || '').trim();
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!m) return s;
    const year = parseInt(m[1], 10);
    const month = parseInt(m[2], 10);
    const q = Math.floor((month - 1) / 3) + 1;
    return `Q${q} ${year}`;
  };

  const formatDate = (dateStr: string) => {
    const s = String(dateStr || '').trim();

    // Backend usually sends Date as YYYY-MM-DD. Parsing with new Date() shifts by timezone (-03 => previous day).
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (m) {
      const [, yyyy, mm, dd] = m;
      return `${dd}/${mm}/${yyyy}`;
    }

    const d = new Date(s);
    const dd = String(d.getUTCDate()).padStart(2, '0');
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    const yyyy = String(d.getUTCFullYear());
    return `${dd}/${mm}/${yyyy}`;
  };

  const handleApplyClick = async (investor: InvestorSummary) => {
    const percentage = parseFloat(percentages[investor.investor_id] || '30');

    if (Number.isNaN(percentage) || percentage <= 0 || percentage > 100) {
      setFlash({ type: 'error', message: 'El porcentaje debe estar entre 0 y 100' });
      return;
    }

    try {
      const response = (await api.calculateTradingFee({
        investor_id: investor.investor_id,
        fee_percentage: percentage,
        period_start: selectedQuarter?.period_start,
        period_end: selectedQuarter?.period_end,
      })) as TradingFeeCalculation;

      setConfirmModal(response);
      setNotes('');
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al calcular comisión' });
    }
  };

  const handleConfirmApply = async () => {
    if (!confirmModal) return;

    try {
      setApplying(true);
      await api.applyTradingFee({
        investor_id: confirmModal.investor_id,
        fee_percentage: confirmModal.fee_percentage,
        notes: notes || undefined,
        period_start: confirmModal.period_start,
        period_end: confirmModal.period_end,
      });

      setFlash({ type: 'success', message: 'Comisión aplicada exitosamente' });
      setConfirmModal(null);
      setNotes('');
      await loadInvestorsSummary(selectedQuarter?.period_start, selectedQuarter?.period_end);
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al aplicar comisión' });
    } finally {
      setApplying(false);
    }
  };

  const filteredInvestors = useMemo(() => {
    const q = investorFilter.trim().toLowerCase();
    if (!q) return investors;
    return investors.filter((inv) => {
      const name = String(inv.investor_name || '').toLowerCase();
      const email = String(inv.investor_email || '').toLowerCase();
      return name.includes(q) || email.includes(q);
    });
  }, [investors, investorFilter]);

  if (loading) {
    return <div className="p-6 text-gray-600">Cargando...</div>;
  }

  if (error) {
    return <div className="p-6 text-red-600">{error}</div>;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Comisiones</h1>
        <p className="mt-1 text-sm text-gray-600">Aplicar Trading Fees por período trimestral.</p>

        <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
          <div className="flex flex-col gap-1">
            <label className="text-sm font-medium text-gray-700">Trimestre</label>
            <select
              className="h-10 rounded border border-gray-300 bg-white px-3 text-sm"
              value={`${selectedQuarter?.period_start}..${selectedQuarter?.period_end}`}
              onChange={(e) => {
                const v = e.target.value;
                const opt = quarterOptions.find((o) => `${o.period_start}..${o.period_end}` === v);
                if (opt) setSelectedQuarter(opt);
              }}
            >
              {quarterOptions.map((o) => (
                <option key={`${o.period_start}..${o.period_end}`} value={`${o.period_start}..${o.period_end}`}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-1 flex-col gap-1 min-w-[240px]">
            <label className="text-sm font-medium text-gray-700">Inversor</label>
            <div className="flex items-center gap-2">
              <input
                type="text"
                value={investorFilter}
                onChange={(e) => setInvestorFilter(e.target.value)}
                placeholder="Buscar por nombre o email..."
                className="h-10 w-full rounded border border-gray-300 bg-white px-3 text-sm"
              />
              {investorFilter ? (
                <button
                  type="button"
                  onClick={() => setInvestorFilter('')}
                  className="h-10 rounded border border-gray-300 bg-white px-3 text-sm text-gray-700 hover:bg-gray-50"
                >
                  Limpiar
                </button>
              ) : null}
            </div>
          </div>
        </div>

      {flash ? (
        <div
          data-testid="flash"
          className={
            `mt-4 mb-4 rounded-lg border px-4 py-3 text-sm ` +
            (flash.type === 'success'
              ? 'border-green-200 bg-green-50 text-green-800'
              : 'border-red-200 bg-red-50 text-red-800')
          }
        >
          <div className="flex items-start justify-between gap-3">
            <span className="leading-5">{flash.message}</span>
            <button
              type="button"
              onClick={() => setFlash(null)}
              className="rounded px-2 py-1 text-xs font-medium hover:bg-black/5"
            >
              Cerrar
            </button>
          </div>
        </div>
      ) : null}

      </div>
      <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Inversor</th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-700">Período</th>
              <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Rendimientos</th>
              <th className="px-6 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-700">%</th>
              <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-700">Comisión</th>
              <th className="px-6 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-700">Acción</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white">
            {filteredInvestors.map((investor) => {
              const isSelectedQuarterClosed = !!selectedQuarter?.is_closed;
              const isApplied = !!investor.already_applied;
              const appliedPct = typeof investor.applied_fee_percentage === 'number' ? investor.applied_fee_percentage : null;
              const percentage = parseFloat(percentages[investor.investor_id] || (appliedPct !== null ? String(appliedPct) : '30'));
              const displayPct = isApplied && appliedPct !== null ? appliedPct : percentage;

              const feeAmount = investor.has_profit ? investor.profit_amount * (displayPct / 100) : 0;
              const shownFeeAmount = isApplied && typeof investor.applied_fee_amount === 'number' ? investor.applied_fee_amount : feeAmount;

              return (
                <tr key={investor.investor_id} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <div className="text-sm font-medium text-gray-900">{investor.investor_name}</div>
                    <div className="text-xs text-gray-500">{investor.investor_email}</div>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-900">
                    <div className="font-medium">{formatQuarterLabel(investor.period_start)}</div>
                    <div className="text-xs text-gray-500">{formatDate(investor.period_start)} al {formatDate(investor.period_end)}</div>
                  </td>
                  <td className="px-6 py-4 text-right text-sm">
                    <div className="flex flex-col items-end gap-1">
                      {investor.has_profit ? (
                        <span className="font-semibold text-green-600">{formatCurrency(investor.profit_amount)}</span>
                      ) : (
                        <span className="text-gray-400">Sin ganancias</span>
                      )}

                      {Array.isArray(investor.monthly_profits) && investor.monthly_profits.length > 0 ? (
                        <button
                          type="button"
                          className="inline-flex items-center gap-1 text-xs text-gray-500 hover:text-gray-700"
                          onClick={() => setDetailModal(investor)}
                        >
                          <span>Detalle</span>
                          <svg
                            aria-hidden
                            viewBox="0 0 24 24"
                            className="h-4 w-4 text-gray-500"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="2"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          >
                            <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                            <circle cx="12" cy="12" r="3" />
                          </svg>
                        </button>
                      ) : null}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-center">
                    <input
                      type="number"
                      min="0"
                      max="100"
                      step="0.1"
                      value={isApplied && appliedPct !== null ? String(appliedPct) : (percentages[investor.investor_id] || '30')}
                      onChange={(e) => handlePercentageChange(investor.investor_id, e.target.value)}
                      disabled={!investor.has_profit || isApplied || !isSelectedQuarterClosed}
                      className="w-20 rounded border border-gray-300 px-2 py-1 text-center text-sm disabled:bg-gray-100"
                    />
                  </td>
                  <td className="px-6 py-4 text-right">
                    {investor.has_profit ? (
                      <span className="font-semibold text-purple-600">{formatCurrency(shownFeeAmount)}</span>
                    ) : (
                      <span className="text-gray-400">—</span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-center">
                    {!isSelectedQuarterClosed ? (
                      <span className="text-xs text-gray-500">Pendiente</span>
                    ) : isApplied ? (
                      <span className="text-xs text-gray-500">Realizada</span>
                    ) : investor.has_profit ? (
                      <button
                        onClick={() => void handleApplyClick(investor)}
                        className="rounded bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700"
                      >
                        Aplicar
                      </button>
                    ) : (
                      <span className="text-xs text-gray-500">No corresponde</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {detailModal ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-lg overflow-hidden rounded-2xl bg-white shadow-2xl">
            <div className="flex items-start justify-between border-b border-gray-100 px-5 py-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-900">Detalle de rentabilidad mensual</h3>
                <p className="mt-0.5 text-sm text-gray-600">
                  {detailModal.investor_name} · {formatDate(detailModal.period_start)} al {formatDate(detailModal.period_end)}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setDetailModal(null)}
                className="rounded-lg px-3 py-1 text-sm font-medium text-gray-600 hover:bg-gray-50"
              >
                Cerrar
              </button>
            </div>

            <div className="px-5 py-4">
              <div className="rounded-xl border border-gray-100 bg-gray-50 p-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-gray-700">Total trimestre</span>
                  <span
                    className={
                      (detailModal.profit_amount ?? 0) > 0
                        ? 'text-sm font-semibold text-green-700'
                        : (detailModal.profit_amount ?? 0) < 0
                          ? 'text-sm font-semibold text-red-700'
                          : 'text-sm font-semibold text-gray-700'
                    }
                  >
                    {formatCurrency(detailModal.profit_amount ?? 0)}
                  </span>
                </div>
              </div>

              <div className="mt-4 overflow-hidden rounded-xl border border-gray-200">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-white">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Mes</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">Rendimiento</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100 bg-white">
                    {(detailModal.monthly_profits || []).map((mp) => {
                      const amt = Number(mp.amount) || 0;
                      const cls = amt > 0 ? 'text-green-700' : amt < 0 ? 'text-red-700' : 'text-gray-500';
                      return (
                        <tr key={mp.month}>
                          <td className="px-4 py-3 text-sm text-gray-900">{formatMonthLabel(mp.month)}</td>
                          <td className={"px-4 py-3 text-right text-sm font-semibold " + cls}>{formatCurrency(amt)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              <div className="mt-4 text-xs text-gray-500">
                Nota: el total del trimestre es la suma de los 3 meses (puede incluir meses negativos).
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {confirmModal ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4">
          <div className="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-xl font-bold text-gray-900">¿Aplicar comisión?</h2>

            <div className="mb-4 space-y-2 rounded-lg bg-purple-50 p-4">
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Inversor:</span>
                <span className="text-sm font-semibold">{confirmModal.investor_name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Período:</span>
                <span className="text-sm">
                  {formatDate(confirmModal.period_start)} - {formatDate(confirmModal.period_end)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Ganancias:</span>
                <span className="text-sm font-semibold text-green-600">{formatCurrency(confirmModal.profit_amount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Porcentaje:</span>
                <span className="text-sm font-semibold">{confirmModal.fee_percentage}%</span>
              </div>
              <div className="flex justify-between border-t border-purple-200 pt-2">
                <span className="text-sm text-gray-600">Comisión a cobrar:</span>
                <span className="text-lg font-bold text-purple-600">{formatCurrency(confirmModal.fee_amount)}</span>
              </div>
            </div>

            <div className="mb-4 space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Capital actual:</span>
                <span className="font-semibold">{formatCurrency(confirmModal.current_balance)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Después de comisión:</span>
                <span className="font-semibold text-green-600">{formatCurrency(confirmModal.balance_after_fee)}</span>
              </div>
            </div>

            <div className="mb-4">
              <label className="mb-1 block text-sm font-medium text-gray-700">Notas (opcional):</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={3}
                className="w-full rounded border border-gray-300 px-3 py-2 text-sm"
                placeholder="Agregar notas..."
              />
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setConfirmModal(null)}
                disabled={applying}
                className="flex-1 rounded border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
              >
                Cancelar
              </button>
              <button
                onClick={() => void handleConfirmApply()}
                disabled={applying}
                className="flex-1 rounded bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50"
              >
                {applying ? 'Aplicando...' : 'Confirmar y Aplicar'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
};
