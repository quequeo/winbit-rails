import { useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';
import { Select } from '../components/ui/Select';
import { Input } from '../components/ui/Input';
import { Button } from '../components/ui/Button';
import { DatePicker } from '../components/ui/DatePicker';

type InvestorSummary = {
  investor_id: string;
  investor_name: string;
  investor_email: string;
  trading_fee_frequency?: 'MONTHLY' | 'QUARTERLY' | 'SEMESTRAL' | 'ANNUAL';
  current_balance: number;
  period_start: string;
  period_end: string;
  profit_amount: number;
  has_profit: boolean;
  already_applied?: boolean;
  applied_fee_id?: string;
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

type TradingFeeEdit = {
  applied_fee_id: string;
  investor_id: string;
  investor_name: string;
  period_start: string;
  period_end: string;
  profit_amount: number;
  current_balance: number;
  fee_percentage: number;
  fee_amount: number;
};

export const TradingFeesPage = () => {
  const [investors, setInvestors] = useState<InvestorSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [percentages, setPercentages] = useState<Record<string, string>>({});
  const [confirmModal, setConfirmModal] = useState<TradingFeeCalculation | null>(null);
  const [editModal, setEditModal] = useState<TradingFeeEdit | null>(null);
  const [applying, setApplying] = useState(false);
  const [refApplying, setRefApplying] = useState(false);
  const [notes, setNotes] = useState('');
  const [editNotes, setEditNotes] = useState('');
  const [editPercentage, setEditPercentage] = useState('30');
  const [investorFilter, setInvestorFilter] = useState('');
  const [flash, setFlash] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const [detailModal, setDetailModal] = useState<InvestorSummary | null>(null);
  const [refInvestorId, setRefInvestorId] = useState<string>('');
  const [refAmount, setRefAmount] = useState<string>('');
  const [refAppliedAt, setRefAppliedAt] = useState<string>('');
  const [deleteConfirm, setDeleteConfirm] = useState<{
    open: boolean;
    feeId: string | null;
    investorName: string;
    periodStart: string;
    periodEnd: string;
  }>({ open: false, feeId: null, investorName: '', periodStart: '', periodEnd: '' });
  const PAGE_SIZE_OPTIONS = [10, 20, 50] as const;
  const [pageSize, setPageSize] = useState<(typeof PAGE_SIZE_OPTIONS)[number]>(20);
  const [page, setPage] = useState(1);

  useEffect(() => {
    void loadInvestorsSummary(undefined, undefined);
  }, []);

  useEffect(() => {
    if (!flash) return;
    const t = setTimeout(() => setFlash(null), 4000);
    return () => clearTimeout(t);
  }, [flash]);

  const loadInvestorsSummary = async (period_start?: string, period_end?: string, opts?: { suppressError?: boolean }) => {
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
      if (!opts?.suppressError) {
        setError(err.message || 'Error al cargar inversores');
      }
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

  const formatPeriodLabel = (inv: InvestorSummary) => {
    if (inv.trading_fee_frequency === 'ANNUAL') {
      const y = String(inv.period_start || '').slice(0, 4);
      return y ? `Año ${y}` : 'Año';
    }
    if (inv.trading_fee_frequency === 'SEMESTRAL') {
      const startMonth = String(inv.period_start || '').slice(5, 7);
      const y = String(inv.period_start || '').slice(0, 4);
      if (startMonth === '01') return `Sem 1 ${y}`;
      if (startMonth === '07') return `Sem 2 ${y}`;
      return y ? `Semestre ${y}` : 'Semestre';
    }
    if (inv.trading_fee_frequency === 'MONTHLY') {
      const s = String(inv.period_start || '').trim();
      const m = s.match(/^(\d{4})-(\d{2})-\d{2}$/);
      if (!m) return 'Mes';
      const year = m[1];
      const mm = parseInt(m[2], 10);
      const names = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return `${names[mm - 1] || m[2]} ${year}`;
    }
    return formatQuarterLabel(inv.period_start);
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
        period_start: investor.period_start,
        period_end: investor.period_end,
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

      await loadInvestorsSummary(undefined, undefined, { suppressError: true });
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al aplicar comisión' });
    } finally {
      setApplying(false);
    }
  };

  const handleEditClick = (investor: InvestorSummary) => {
    if (!investor.applied_fee_id) {
      setFlash({ type: 'error', message: 'No se encontró el ID de la comisión aplicada' });
      return;
    }
    const pct = typeof investor.applied_fee_percentage === 'number' ? investor.applied_fee_percentage : 30;
    const feeAmt = typeof investor.applied_fee_amount === 'number' ? investor.applied_fee_amount : 0;
    setEditPercentage(String(pct));
    setEditNotes('');
    setEditModal({
      applied_fee_id: investor.applied_fee_id,
      investor_id: investor.investor_id,
      investor_name: investor.investor_name,
      period_start: investor.period_start,
      period_end: investor.period_end,
      profit_amount: investor.profit_amount,
      current_balance: investor.current_balance,
      fee_percentage: pct,
      fee_amount: feeAmt,
    });
  };

  const handleConfirmEdit = async () => {
    if (!editModal) return;

    const nextPct = parseFloat(editPercentage || '');
    if (Number.isNaN(nextPct) || nextPct <= 0 || nextPct > 100) {
      setFlash({ type: 'error', message: 'El porcentaje debe estar entre 0 y 100' });
      return;
    }

    try {
      setApplying(true);
      await api.updateTradingFee(editModal.applied_fee_id, {
        fee_percentage: nextPct,
        notes: editNotes || undefined,
      });
      setFlash({ type: 'success', message: 'Comisión actualizada exitosamente' });
      setEditModal(null);
      setEditNotes('');
      await loadInvestorsSummary(undefined, undefined);
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al actualizar comisión' });
    } finally {
      setApplying(false);
    }
  };

  const handleApplyReferralCommission = async () => {
    const investorId = refInvestorId.trim();
    const amount = Number(refAmount);
    if (!investorId) {
      setFlash({ type: 'error', message: 'Seleccioná un inversor' });
      return;
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      setFlash({ type: 'error', message: 'Ingresá un monto mayor a 0' });
      return;
    }

    try {
      setRefApplying(true);
      await api.applyReferralCommission(investorId, {
        amount,
        applied_at: refAppliedAt.trim() ? refAppliedAt.trim() : undefined,
      });

      setFlash({ type: 'success', message: 'Comisión por referido aplicada' });
      setRefAmount('');
      setRefAppliedAt('');
      await loadInvestorsSummary(undefined, undefined);
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al aplicar comisión por referido' });
    } finally {
      setRefApplying(false);
    }
  };

  const requestDeleteFee = (feeId: string, investorName: string, periodStart: string, periodEnd: string) => {
    setDeleteConfirm({ open: true, feeId, investorName, periodStart, periodEnd });
  };

  const confirmDeleteFee = async () => {
    if (!deleteConfirm.feeId) return;
    try {
      setApplying(true);
      await api.deleteTradingFee(deleteConfirm.feeId);
      setFlash({ type: 'success', message: 'Comisión eliminada (anulada) exitosamente' });
      setEditModal(null);
      setEditNotes('');
      await loadInvestorsSummary(undefined, undefined);
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al eliminar comisión' });
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

  useEffect(() => {
    setPage(1);
  }, [investorFilter, pageSize, investors.length]);

  const totalPages = Math.max(1, Math.ceil(filteredInvestors.length / pageSize));
  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  const visibleInvestors = useMemo(() => {
    const start = (page - 1) * pageSize;
    return filteredInvestors.slice(start, start + pageSize);
  }, [filteredInvestors, page, pageSize]);

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
        <p className="mt-1 text-sm text-gray-600">Aplicar Trading Fees por período (mensual, trimestral, semestral o anual según inversor).</p>

        <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
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

        <div className="mt-4 rounded-lg border border-blue-200 bg-blue-50 p-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div className="min-w-0">
              <div className="text-sm font-semibold text-blue-900">Comisión por referido (manual)</div>
              <div className="mt-0.5 text-xs text-blue-900/70">
                Carga un monto puntual al balance del inversor. Si usás una fecha pasada, se recalcula el historial.
              </div>
            </div>
          </div>

          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-4">
            <div className="sm:col-span-2">
              <label className="mb-1 block text-xs font-medium text-blue-900/80">Inversor</label>
              <Select
                portal
                value={refInvestorId}
                onChange={(v) => setRefInvestorId(v)}
                options={[
                  { value: '', label: 'Seleccionar...' },
                  ...investors.map((inv) => ({
                    value: inv.investor_id,
                    label: `${inv.investor_name} — ${inv.investor_email}`,
                  })),
                ]}
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-blue-900/80">Monto (USD)</label>
              <Input
                type="number"
                inputMode="decimal"
                value={refAmount}
                onChange={(e) => setRefAmount(e.target.value)}
                onWheel={(e) => {
                  // Prevent mouse wheel from changing number inputs (common UX bug on desktop trackpads/mice)
                  e.currentTarget.blur();
                }}
                placeholder="Ej: 50"
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-blue-900/80">
                Fecha (opcional)
              </label>
              <DatePicker value={refAppliedAt} onChange={setRefAppliedAt} />
            </div>
          </div>

          <div className="mt-3 flex justify-end">
            <Button
              onClick={() => void handleApplyReferralCommission()}
              disabled={refApplying}
              className="bg-blue-600 hover:bg-blue-700"
            >
              {refApplying ? 'Aplicando...' : 'Aplicar comisión'}
            </Button>
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
      {/* Mobile: cards */}
      <div className="grid gap-3 md:hidden">
        {visibleInvestors.map((investor) => {
          const isApplied = !!investor.already_applied;
          const appliedPct = typeof investor.applied_fee_percentage === 'number' ? investor.applied_fee_percentage : null;
          const rawPct = percentages[investor.investor_id];
          const pct = isApplied && appliedPct !== null ? appliedPct : rawPct === '' ? null : parseFloat(rawPct ?? '30');
          const pctIsValid = pct !== null && Number.isFinite(pct);
          const feeAmount =
            investor.has_profit && pctIsValid ? investor.profit_amount * (pct! / 100) : null;
          const shownFeeAmount =
            isApplied && typeof investor.applied_fee_amount === 'number'
              ? investor.applied_fee_amount
              : feeAmount;

          return (
            <div key={investor.investor_id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold text-gray-900">{investor.investor_name}</div>
                  <div className="truncate text-xs text-gray-500">{investor.investor_email}</div>
                </div>
                <span className="shrink-0 inline-flex rounded-full bg-purple-50 px-2 py-0.5 text-[11px] font-semibold text-purple-800">
                  {investor.trading_fee_frequency === 'ANNUAL'
                    ? 'Anual'
                    : investor.trading_fee_frequency === 'SEMESTRAL'
                      ? 'Semestral'
                      : investor.trading_fee_frequency === 'MONTHLY'
                        ? 'Mensual'
                        : 'Trimestral'}
                </span>
              </div>

              <div className="mt-3 grid grid-cols-2 gap-3">
                <div>
                  <div className="text-[11px] font-medium uppercase tracking-wide text-gray-500">Período</div>
                  <div className="mt-1 text-sm font-medium text-gray-900">{formatPeriodLabel(investor)}</div>
                  <div className="mt-0.5 text-xs text-gray-500">
                    {formatDate(investor.period_start)} al {formatDate(investor.period_end)}
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-[11px] font-medium uppercase tracking-wide text-gray-500">Rendimientos</div>
                  <div className="mt-1">
                    {investor.has_profit ? (
                      <span className="text-sm font-semibold text-green-600">{formatCurrency(investor.profit_amount)}</span>
                    ) : (
                      <span className="text-sm text-gray-400">Sin ganancias</span>
                    )}
                  </div>
                  {Array.isArray(investor.monthly_profits) && investor.monthly_profits.length > 0 ? (
                    <button
                      type="button"
                      className="mt-1 inline-flex items-center justify-end gap-1 text-xs text-gray-500 hover:text-gray-700"
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
              </div>

              <div className="mt-3 grid grid-cols-2 items-center gap-3">
                <div>
                  <div className="text-[11px] font-medium uppercase tracking-wide text-gray-500">Porcentaje</div>
                  <div className="mt-1 flex items-center gap-2">
                    <input
                      type="number"
                      min="0"
                      max="100"
                      step="0.1"
                      value={
                        isApplied && appliedPct !== null
                          ? String(appliedPct)
                          : rawPct !== undefined
                            ? rawPct
                            : '30'
                      }
                      onChange={(e) => handlePercentageChange(investor.investor_id, e.target.value)}
                      onWheel={(e) => {
                        e.currentTarget.blur();
                      }}
                      disabled={!investor.has_profit || isApplied}
                      className="h-9 w-20 rounded border border-gray-300 px-2 text-sm disabled:bg-gray-100"
                    />
                    <span className="text-sm font-medium text-gray-700">%</span>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-[11px] font-medium uppercase tracking-wide text-gray-500">Comisión</div>
                  <div className="mt-2">
                    {investor.has_profit ? (
                      <span className="text-sm font-semibold text-purple-600">
                        {shownFeeAmount === null ? '—' : formatCurrency(shownFeeAmount)}
                      </span>
                    ) : (
                      <span className="text-sm text-gray-400">—</span>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-4 flex items-center justify-end gap-2">
                {isApplied ? (
                  <>
                    <button
                      type="button"
                      title="Editar"
                      onClick={() => handleEditClick(investor)}
                      className="rounded border border-gray-300 bg-white p-2 text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                      disabled={applying}
                    >
                      <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
                        />
                      </svg>
                    </button>
                    <button
                      type="button"
                      title="Eliminar"
                      onClick={() => {
                        if (!investor.applied_fee_id) {
                          setFlash({ type: 'error', message: 'No se encontró el ID de la comisión aplicada' });
                          return;
                        }
                        requestDeleteFee(investor.applied_fee_id, investor.investor_name, investor.period_start, investor.period_end);
                      }}
                      className="rounded border border-red-200 bg-white p-2 text-red-600 hover:bg-red-50 disabled:opacity-50"
                      disabled={applying}
                    >
                      <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                        />
                      </svg>
                    </button>
                  </>
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
              </div>
            </div>
          );
        })}
      </div>

      {/* Desktop: table */}
      <div className="hidden md:block overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
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
            {visibleInvestors.map((investor) => {
              const isApplied = !!investor.already_applied;
              const appliedPct = typeof investor.applied_fee_percentage === 'number' ? investor.applied_fee_percentage : null;
              const rawPct = percentages[investor.investor_id];
              const pct = isApplied && appliedPct !== null ? appliedPct : rawPct === '' ? null : parseFloat(rawPct ?? '30');
              const pctIsValid = pct !== null && Number.isFinite(pct);
              const feeAmount = investor.has_profit && pctIsValid ? investor.profit_amount * (pct! / 100) : null;
              const shownFeeAmount =
                isApplied && typeof investor.applied_fee_amount === 'number'
                  ? investor.applied_fee_amount
                  : feeAmount;

              return (
                <tr key={investor.investor_id} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <div className="text-sm font-medium text-gray-900">{investor.investor_name}</div>
                    <div className="text-xs text-gray-500">{investor.investor_email}</div>
                    <div className="mt-1">
                      <span className="inline-flex rounded-full bg-purple-50 px-2 py-0.5 text-[11px] font-semibold text-purple-800">
                        {investor.trading_fee_frequency === 'ANNUAL'
                          ? 'Anual'
                          : investor.trading_fee_frequency === 'SEMESTRAL'
                            ? 'Semestral'
                            : investor.trading_fee_frequency === 'MONTHLY'
                              ? 'Mensual'
                              : 'Trimestral'}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-900">
                    <div className="font-medium">{formatPeriodLabel(investor)}</div>
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
                      value={
                        isApplied && appliedPct !== null
                          ? String(appliedPct)
                          : rawPct !== undefined
                            ? rawPct
                            : '30'
                      }
                      onChange={(e) => handlePercentageChange(investor.investor_id, e.target.value)}
                      onWheel={(e) => {
                        // Prevent mouse wheel from changing number inputs (common UX bug on desktop trackpads/mice)
                        e.currentTarget.blur();
                      }}
                      disabled={!investor.has_profit || isApplied}
                      className="w-20 rounded border border-gray-300 px-2 py-1 text-center text-sm disabled:bg-gray-100"
                    />
                  </td>
                  <td className="px-6 py-4 text-right">
                    {investor.has_profit ? (
                      <span className="font-semibold text-purple-600">
                        {shownFeeAmount === null ? '—' : formatCurrency(shownFeeAmount)}
                      </span>
                    ) : (
                      <span className="text-gray-400">—</span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-center">
                    {isApplied ? (
                      <div className="flex items-center justify-center gap-2">
                        <button
                          type="button"
                          title="Editar"
                          onClick={() => handleEditClick(investor)}
                          className="rounded border border-gray-300 bg-white p-2 text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                          disabled={applying}
                        >
                          <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2">
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
                            />
                          </svg>
                        </button>
                        <button
                          type="button"
                          title="Eliminar"
                          onClick={() => {
                            if (!investor.applied_fee_id) {
                              setFlash({ type: 'error', message: 'No se encontró el ID de la comisión aplicada' });
                              return;
                            }
                            requestDeleteFee(
                              investor.applied_fee_id,
                              investor.investor_name,
                              investor.period_start,
                              investor.period_end,
                            );
                          }}
                          className="rounded border border-red-200 bg-white p-2 text-red-600 hover:bg-red-50 disabled:opacity-50"
                          disabled={applying}
                        >
                          <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2">
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                            />
                          </svg>
                        </button>
                      </div>
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

      <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2 text-sm text-gray-600">
          <span>Filas por página:</span>
          <Select
            portal
            className="w-24"
            value={String(pageSize)}
            onChange={(v) => setPageSize(parseInt(v, 10) as (typeof PAGE_SIZE_OPTIONS)[number])}
            options={PAGE_SIZE_OPTIONS.map((n) => ({ value: String(n), label: String(n) }))}
          />
        </div>

        <div className="flex items-center justify-between gap-3">
          <button
            type="button"
            className="rounded border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
          >
            Anterior
          </button>
          <div className="text-sm text-gray-700">
            Página <span className="font-semibold">{page}</span> de <span className="font-semibold">{totalPages}</span>
          </div>
          <button
            type="button"
            className="rounded border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
            disabled={page >= totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
          >
            Siguiente
          </button>
        </div>
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
                  <span className="text-sm font-medium text-gray-700">Total período</span>
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
                Nota: el total del período es la suma de los meses (puede incluir meses negativos).
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

      {editModal ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4">
          <div className="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-xl font-bold text-gray-900">Editar comisión aplicada</h2>

            {(() => {
              const currentFee = editModal.fee_amount;
              const nextPct = parseFloat(editPercentage || '');
              const nextFee = Number.isNaN(nextPct) ? null : (editModal.profit_amount * (nextPct / 100)).toFixed(2);
              const nextFeeNum = nextFee === null ? null : Number(nextFee);
              const delta = nextFeeNum === null ? null : (nextFeeNum - currentFee);
              const balanceAfter = delta === null ? null : (editModal.current_balance - delta);

              return (
                <>
                  <div className="mb-4 space-y-2 rounded-lg bg-purple-50 p-4">
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-600">Inversor:</span>
                      <span className="text-sm font-semibold">{editModal.investor_name}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-600">Período:</span>
                      <span className="text-sm">
                        {formatDate(editModal.period_start)} - {formatDate(editModal.period_end)}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-600">Ganancias:</span>
                      <span className="text-sm font-semibold text-green-700">{formatCurrency(editModal.profit_amount)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-600">Comisión actual:</span>
                      <span className="text-sm font-semibold text-gray-900">{formatCurrency(currentFee)}</span>
                    </div>
                  </div>

                  <div className="mb-4">
                    <label className="mb-1 block text-sm font-medium text-gray-700">Nuevo porcentaje</label>
                    <input
                      type="number"
                      min="0"
                      max="100"
                      step="0.1"
                      value={editPercentage}
                      onChange={(e) => setEditPercentage(e.target.value)}
                      onWheel={(e) => {
                        // Prevent mouse wheel from changing number inputs (common UX bug on desktop trackpads/mice)
                        e.currentTarget.blur();
                      }}
                      className="w-full rounded border border-gray-300 px-3 py-2 text-sm"
                    />
                    <div className="mt-2 text-sm text-gray-700">
                      Nuevo monto: <span className="font-semibold">{nextFeeNum === null ? '—' : formatCurrency(nextFeeNum)}</span>
                    </div>
                    <div className="mt-1 text-sm text-gray-700">
                      Diferencia: <span className="font-semibold">{delta === null ? '—' : formatCurrency(delta)}</span>
                    </div>
                    <div className="mt-1 text-sm text-gray-700">
                      Balance después del ajuste:{' '}
                      <span className="font-semibold">{balanceAfter === null ? '—' : formatCurrency(balanceAfter)}</span>
                    </div>
                    <p className="mt-2 text-xs text-gray-500">
                      Esto no reescribe historia: crea un ajuste contable por la diferencia y actualiza el balance actual.
                    </p>
                  </div>

                  <div className="mb-4">
                    <label className="mb-1 block text-sm font-medium text-gray-700">Notas (opcional)</label>
                    <textarea
                      value={editNotes}
                      onChange={(e) => setEditNotes(e.target.value)}
                      rows={3}
                      className="w-full rounded border border-gray-300 px-3 py-2 text-sm"
                      placeholder="Agregar notas..."
                    />
                  </div>

                  <div className="flex gap-3">
                    <button
                      onClick={() => setEditModal(null)}
                      disabled={applying}
                      className="flex-1 rounded border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                    >
                      Cancelar
                    </button>
                    <button
                      type="button"
                      onClick={() =>
                        requestDeleteFee(editModal.applied_fee_id, editModal.investor_name, editModal.period_start, editModal.period_end)
                      }
                      disabled={applying}
                      className="rounded bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50"
                    >
                      Eliminar
                    </button>
                    <button
                      onClick={() => void handleConfirmEdit()}
                      disabled={applying}
                      className="flex-1 rounded bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50"
                    >
                      {applying ? 'Guardando...' : 'Guardar'}
                    </button>
                  </div>
                </>
              );
            })()}
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        isOpen={deleteConfirm.open}
        onClose={() => setDeleteConfirm({ open: false, feeId: null, investorName: '', periodStart: '', periodEnd: '' })}
        onConfirm={() => void confirmDeleteFee()}
        title="Eliminar comisión aplicada"
        message={
          <>
            ¿Querés eliminar (anular) la comisión de <span className="font-semibold">{deleteConfirm.investorName}</span>?
            <br />
            <span className="text-gray-600">
              Período: {formatDate(deleteConfirm.periodStart)} - {formatDate(deleteConfirm.periodEnd)}
            </span>
            <br />
            <span className="text-gray-600">Esto devolverá el monto al balance del inversor.</span>
          </>
        }
        confirmText="Eliminar"
        cancelText="Cancelar"
        confirmVariant="danger"
      />
    </div>
  );
};
