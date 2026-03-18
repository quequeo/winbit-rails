import { useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { Select } from "../components/ui/Select";
import { formatDateAR, formatCurrencyAR } from "../lib/formatters";
import type { ApiInvestor } from "../types";

type Frequency = "MONTHLY" | "QUARTERLY" | "SEMESTRAL" | "ANNUAL";

const FREQUENCY_OPTIONS: { value: "per_investor" | Frequency; label: string }[] = [
  { value: "per_investor", label: "Por inversor (auto)" },
  { value: "MONTHLY", label: "Mensual" },
  { value: "QUARTERLY", label: "Trimestral" },
  { value: "SEMESTRAL", label: "Semestral" },
  { value: "ANNUAL", label: "Anual" },
];

const buildMonthOptions = () => {
  const opts: { value: string; label: string; start: string; end: string }[] = [];
  const now = new Date();
  const base = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  for (let i = 0; i < 12; i++) {
    const d = new Date(base.getFullYear(), base.getMonth() - i, 1);
    const y = d.getFullYear();
    const m = d.getMonth() + 1;
    const lastDay = new Date(y, m, 0).getDate();
    const start = `${y}-${String(m).padStart(2, "0")}-01`;
    const end = `${y}-${String(m).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
    const names = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
    opts.push({ value: `${start}|${end}`, label: `${names[m - 1]} ${y}`, start, end });
  }
  return opts;
};

const buildQuarterOptions = () => {
  const opts: { value: string; label: string; start: string; end: string }[] = [];
  const now = new Date();
  const curQ = Math.floor(now.getMonth() / 3) + 1;
  let y = now.getFullYear();
  let q = curQ - 1;
  if (q <= 0) { q = 4; y -= 1; }
  for (let i = 0; i < 8; i++) {
    let qy = y;
    let qq = q - i;
    while (qq <= 0) { qq += 4; qy -= 1; }
    const sm = (qq - 1) * 3 + 1;
    const em = qq * 3;
    const start = `${qy}-${String(sm).padStart(2, "0")}-01`;
    const lastDay = new Date(qy, em, 0).getDate();
    const end = `${qy}-${String(em).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
    opts.push({ value: `${start}|${end}`, label: `Q${qq} ${qy}`, start, end });
  }
  return opts;
};

const buildSemesterOptions = () => {
  const opts: { value: string; label: string; start: string; end: string }[] = [];
  const now = new Date();
  let y = now.getFullYear();
  let s = now.getMonth() < 6 ? 2 : 1;
  if (s === 1) { y -= 1; s = 2; } else { s = 1; }
  for (let i = 0; i < 4; i++) {
    let sy = y;
    let ss = s;
    for (let j = 0; j < i; j++) {
      ss -= 1;
      if (ss <= 0) { ss = 2; sy -= 1; }
    }
    const sm = ss === 1 ? 1 : 7;
    const em = ss === 1 ? 6 : 12;
    const start = `${sy}-${String(sm).padStart(2, "0")}-01`;
    const lastDay = new Date(sy, em, 0).getDate();
    const end = `${sy}-${String(em).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
    const label = ss === 1 ? `1er Sem ${sy}` : `2do Sem ${sy}`;
    opts.push({ value: `${start}|${end}`, label, start, end });
  }
  return opts;
};

const buildYearOptions = () => {
  const opts: { value: string; label: string; start: string; end: string }[] = [];
  const now = new Date();
  for (let i = 1; i <= 3; i++) {
    const y = now.getFullYear() - i;
    const start = `${y}-01-01`;
    const end = `${y}-12-31`;
    opts.push({ value: `${start}|${end}`, label: `${y}`, start, end });
  }
  return opts;
};

export type WithdrawalFeeInfo = {
  fee_amount: number;
  fee_date: string;
  withdrawal_amount: number;
  count: number;
};

export type InvestorSummary = {
  investor_id: string;
  investor_name: string;
  investor_email: string;
  trading_fee_frequency?: Frequency;
  investor_trading_fee_percentage?: number;
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
  period_clipped?: boolean;
  withdrawal_fee_in_period?: WithdrawalFeeInfo;
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
  const [error, setError] = useState("");
  const [percentages, setPercentages] = useState<Record<string, string>>({});
  const [confirmModal, setConfirmModal] = useState<TradingFeeCalculation | null>(null);
  const [editModal, setEditModal] = useState<TradingFeeEdit | null>(null);
  const [applying, setApplying] = useState(false);
  const [notes, setNotes] = useState("");
  const [editNotes, setEditNotes] = useState("");
  const [editPercentage, setEditPercentage] = useState("30");
  const [investorFilter, setInvestorFilter] = useState("");
  const [flash, setFlash] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [detailModal, setDetailModal] = useState<InvestorSummary | null>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<{
    open: boolean;
    feeId: string | null;
    investorName: string;
    periodStart: string;
    periodEnd: string;
  }>({ open: false, feeId: null, investorName: "", periodStart: "", periodEnd: "" });
  const PAGE_SIZE_OPTIONS = [10, 20, 50] as const;
  const [pageSize, setPageSize] = useState<(typeof PAGE_SIZE_OPTIONS)[number]>(20);
  const [page, setPage] = useState(1);

  const [frequencyMode, setFrequencyMode] = useState<"per_investor" | Frequency>("per_investor");
  const [periodValue, setPeriodValue] = useState("");
  const [allInvestors, setAllInvestors] = useState<ApiInvestor[]>([]);
  const [addInvestorId, setAddInvestorId] = useState("");
  const [addingInvestor, setAddingInvestor] = useState(false);
  const [showAddInvestor, setShowAddInvestor] = useState(false);

  const periodOptions = useMemo(() => {
    switch (frequencyMode) {
      case "MONTHLY": return buildMonthOptions();
      case "QUARTERLY": return buildQuarterOptions();
      case "SEMESTRAL": return buildSemesterOptions();
      case "ANNUAL": return buildYearOptions();
      default: return [];
    }
  }, [frequencyMode]);

  useEffect(() => {
    if (frequencyMode !== "per_investor" && periodOptions.length > 0) {
      setPeriodValue(periodOptions[0].value);
    } else {
      setPeriodValue("");
    }
  }, [frequencyMode, periodOptions]);

  useEffect(() => {
    if (frequencyMode === "per_investor") {
      void loadInvestorsSummary(undefined, undefined, undefined);
    } else if (periodValue) {
      const [start, end] = periodValue.split("|");
      if (start && end) {
        void loadInvestorsSummary(start, end, frequencyMode);
      }
    }
  }, [frequencyMode, periodValue]);

  useEffect(() => {
    api.getAdminInvestors({}).then((res) => {
      const data = (res as { data?: ApiInvestor[] })?.data ?? [];
      setAllInvestors(data);
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (!flash) return;
    const t = setTimeout(() => setFlash(null), 4000);
    return () => clearTimeout(t);
  }, [flash]);

  const loadInvestorsSummary = async (
    period_start?: string,
    period_end?: string,
    frequency?: string,
    opts?: { suppressError?: boolean; investor_id?: string },
  ) => {
    try {
      setLoading(true);
      setError("");
      const response = (await api.getTradingFeesSummary({
        period_start,
        period_end,
        frequency,
        investor_id: opts?.investor_id,
      })) as InvestorSummary[];
      if (opts?.investor_id) {
        setInvestors((prev) => {
          const existingIds = new Set(prev.map((i) => i.investor_id));
          const toAdd = response.filter((r) => !existingIds.has(r.investor_id));
          return [...prev, ...toAdd];
        });
        const newPct: Record<string, string> = {};
        response.forEach((inv) => {
          const applied = typeof inv.applied_fee_percentage === "number" ? inv.applied_fee_percentage : null;
          const investorDefault = typeof inv.investor_trading_fee_percentage === "number" ? inv.investor_trading_fee_percentage : 30;
          newPct[inv.investor_id] = applied !== null ? String(applied) : String(investorDefault);
        });
        if (Object.keys(newPct).length > 0) {
          setPercentages((p) => ({ ...p, ...newPct }));
        }
      } else {
        setInvestors(response);
        const initialPercentages: Record<string, string> = {};
        response.forEach((inv) => {
          const applied = typeof inv.applied_fee_percentage === "number" ? inv.applied_fee_percentage : null;
          const investorDefault = typeof inv.investor_trading_fee_percentage === "number" ? inv.investor_trading_fee_percentage : 30;
          initialPercentages[inv.investor_id] = applied !== null ? String(applied) : String(investorDefault);
        });
        setPercentages(initialPercentages);
      }
    } catch (err: unknown) {
      if (!opts?.suppressError) {
        setError(err instanceof Error ? err.message : "Error al cargar inversores");
      }
    } finally {
      setLoading(false);
    }
  };

  const handleAddInvestor = async () => {
    if (!addInvestorId) return;
    setAddingInvestor(true);
    try {
      const [start, end] = frequencyMode !== "per_investor" && periodValue ? periodValue.split("|") : [undefined, undefined];
      const response = (await api.getTradingFeesSummary({
        period_start: start,
        period_end: end,
        investor_id: addInvestorId,
      })) as InvestorSummary[];
      setAddInvestorId("");
      if (response.length === 0) {
        setFlash({ type: "error", message: "Inversor no encontrado o sin capital invertido en el período" });
      } else {
        setInvestors((prev) => {
          const existingIds = new Set(prev.map((i) => i.investor_id));
          const toAdd = response.filter((r) => !existingIds.has(r.investor_id));
          return [...prev, ...toAdd];
        });
        const newPct: Record<string, string> = {};
        response.forEach((inv) => {
          const applied = typeof inv.applied_fee_percentage === "number" ? inv.applied_fee_percentage : null;
          const investorDefault = typeof inv.investor_trading_fee_percentage === "number" ? inv.investor_trading_fee_percentage : 30;
          newPct[inv.investor_id] = applied !== null ? String(applied) : String(investorDefault);
        });
        setPercentages((p) => ({ ...p, ...newPct }));
        setShowAddInvestor(false);
      }
    } catch {
      setFlash({ type: "error", message: "Error al cargar el inversor" });
    } finally {
      setAddingInvestor(false);
    }
  };

  const handlePercentageChange = (investorId: string, value: string) => {
    setPercentages((prev) => ({ ...prev, [investorId]: value }));
  };

  const formatMonthLabel = (month: string) => {
    const m = String(month || "").match(/^(\d{4})-(\d{2})$/);
    if (!m) return month;
    const year = m[1];
    const mm = parseInt(m[2], 10);
    const names = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
    const name = names[mm - 1] || m[2];
    return `${name} ${year}`;
  };

  const formatPeriodLabel = (inv: InvestorSummary) => {
    if (inv.trading_fee_frequency === "ANNUAL") {
      const y = String(inv.period_start || "").slice(0, 4);
      return y ? `Año ${y}` : "Año";
    }
    if (inv.trading_fee_frequency === "SEMESTRAL") {
      const startMonth = String(inv.period_start || "").slice(5, 7);
      const y = String(inv.period_start || "").slice(0, 4);
      if (startMonth === "01") return `1er Semestre ${y}`;
      if (startMonth === "07") return `2do Semestre ${y}`;
      return y ? `Semestre ${y}` : "Semestre";
    }
    if (inv.trading_fee_frequency === "MONTHLY") {
      const s = String(inv.period_start || "").trim();
      const m = s.match(/^(\d{4})-(\d{2})-\d{2}$/);
      if (!m) return "Mes";
      const year = m[1];
      const mm = parseInt(m[2], 10);
      const names = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];
      return `${names[mm - 1] || m[2]} ${year}`;
    }
    const s = String(inv.period_start || "").trim();
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!m) return s;
    const year = parseInt(m[1], 10);
    const month = parseInt(m[2], 10);
    const q = Math.floor((month - 1) / 3) + 1;
    return `Q${q} ${year}`;
  };

  const formatDate = (dateStr: string) => formatDateAR(dateStr, { time: false });

  const freqLabel = (f?: string) => {
    switch (f) {
      case "ANNUAL": return "Anual";
      case "SEMESTRAL": return "Semestral";
      case "MONTHLY": return "Mensual";
      default: return "Trimestral";
    }
  };

  const handleApplyClick = async (investor: InvestorSummary) => {
    const percentage = parseFloat(percentages[investor.investor_id] || "30");
    if (Number.isNaN(percentage) || percentage <= 0 || percentage > 100) {
      setFlash({ type: "error", message: "El porcentaje debe estar entre 0 y 100" });
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
      setNotes("");
    } catch (err: unknown) {
      setFlash({ type: "error", message: err instanceof Error ? err.message : "Error al calcular comisión" });
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
      setFlash({ type: "success", message: "Comisión aplicada exitosamente" });
      setConfirmModal(null);
      setNotes("");
      const [start, end] = frequencyMode !== "per_investor" && periodValue ? periodValue.split("|") : [undefined, undefined];
      await loadInvestorsSummary(start, end, frequencyMode !== "per_investor" ? frequencyMode : undefined, { suppressError: true });
    } catch (err: unknown) {
      setFlash({ type: "error", message: err instanceof Error ? err.message : "Error al aplicar comisión" });
    } finally {
      setApplying(false);
    }
  };

  const handleEditClick = (investor: InvestorSummary) => {
    if (!investor.applied_fee_id) {
      setFlash({ type: "error", message: "No se encontró el ID de la comisión aplicada" });
      return;
    }
    const pct = typeof investor.applied_fee_percentage === "number" ? investor.applied_fee_percentage : 30;
    const feeAmt = typeof investor.applied_fee_amount === "number" ? investor.applied_fee_amount : 0;
    setEditPercentage(String(pct));
    setEditNotes("");
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
    const nextPct = parseFloat(editPercentage || "");
    if (Number.isNaN(nextPct) || nextPct <= 0 || nextPct > 100) {
      setFlash({ type: "error", message: "El porcentaje debe estar entre 0 y 100" });
      return;
    }
    try {
      setApplying(true);
      await api.updateTradingFee(editModal.applied_fee_id, { fee_percentage: nextPct, notes: editNotes || undefined });
      setFlash({ type: "success", message: "Comisión actualizada exitosamente" });
      setEditModal(null);
      setEditNotes("");
      const [start, end] = frequencyMode !== "per_investor" && periodValue ? periodValue.split("|") : [undefined, undefined];
      await loadInvestorsSummary(start, end, frequencyMode !== "per_investor" ? frequencyMode : undefined);
    } catch (err: unknown) {
      setFlash({ type: "error", message: err instanceof Error ? err.message : "Error al actualizar comisión" });
    } finally {
      setApplying(false);
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
      setFlash({ type: "success", message: "Comisión eliminada (anulada) exitosamente" });
      setEditModal(null);
      setEditNotes("");
      const [start, end] = frequencyMode !== "per_investor" && periodValue ? periodValue.split("|") : [undefined, undefined];
      await loadInvestorsSummary(start, end, frequencyMode !== "per_investor" ? frequencyMode : undefined);
    } catch (err: unknown) {
      setFlash({ type: "error", message: err instanceof Error ? err.message : "Error al eliminar comisión" });
    } finally {
      setApplying(false);
    }
  };

  const filteredInvestors = useMemo(() => {
    const q = investorFilter.trim().toLowerCase();
    if (!q) return investors;
    return investors.filter((inv) => {
      const name = String(inv.investor_name || "").toLowerCase();
      const email = String(inv.investor_email || "").toLowerCase();
      return name.includes(q) || email.includes(q);
    });
  }, [investors, investorFilter]);

  useEffect(() => { setPage(1); }, [investorFilter, pageSize, investors.length]);

  const totalPages = Math.max(1, Math.ceil(filteredInvestors.length / pageSize));
  useEffect(() => { if (page > totalPages) setPage(totalPages); }, [page, totalPages]);

  const visibleInvestors = useMemo(() => {
    const start = (page - 1) * pageSize;
    return filteredInvestors.slice(start, start + pageSize);
  }, [filteredInvestors, page, pageSize]);

  const ClippedBadge = ({ inv }: { inv: InvestorSummary }) => {
    if (!inv.period_clipped || !inv.withdrawal_fee_in_period) return null;
    const wf = inv.withdrawal_fee_in_period;
    return (
      <span
        title={`Período recortado: se cobró ${formatCurrencyAR(wf.fee_amount)} por retiro el ${formatDate(wf.fee_date)}`}
        className="ml-1 inline-flex rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold text-amber-800 cursor-help"
      >
        Recortado
      </span>
    );
  };

  if (loading) return <div className="p-6 text-t-muted">Cargando...</div>;
  if (error) return <div className="p-6 text-error">{error}</div>;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-t-primary">Comisiones</h1>
        <p className="mt-1 text-sm text-t-muted">
          Aplicar Trading Fees por período (mensual, trimestral, semestral o anual según inversor).
        </p>

        <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
          <div className="flex flex-col gap-1 min-w-[160px]">
            <label className="text-sm font-medium text-t-muted">Frecuencia</label>
            <select
              value={frequencyMode}
              onChange={(e) => setFrequencyMode(e.target.value as typeof frequencyMode)}
              className="h-10 rounded border border-b-default bg-dark-card px-3 text-sm text-t-primary"
            >
              {FREQUENCY_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
          </div>

          {frequencyMode !== "per_investor" && periodOptions.length > 0 && (
            <div className="flex flex-col gap-1 min-w-[160px]">
              <label className="text-sm font-medium text-t-muted">Período</label>
              <select
                value={periodValue}
                onChange={(e) => setPeriodValue(e.target.value)}
                className="h-10 rounded border border-b-default bg-dark-card px-3 text-sm text-t-primary"
              >
                {periodOptions.map((o) => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
            </div>
          )}

          <div className="flex flex-1 flex-col gap-1 min-w-[240px]">
            <label className="text-sm font-medium text-t-muted">Buscar en lista</label>
            <div className="flex items-center gap-2">
              <input
                type="text"
                value={investorFilter}
                onChange={(e) => setInvestorFilter(e.target.value)}
                placeholder="Filtrar por nombre o email..."
                className="h-10 w-full rounded border border-b-default bg-dark-card px-3 text-sm"
              />
              {investorFilter ? (
                <button type="button" onClick={() => setInvestorFilter("")} className="h-10 rounded border border-b-default bg-dark-card px-3 text-sm text-t-muted hover:bg-dark-section">
                  Limpiar
                </button>
              ) : null}
            </div>
          </div>

          <div className="flex flex-col gap-1">
            <label className="text-sm font-medium text-t-muted invisible">Acción</label>
            {showAddInvestor ? (
              <div className="flex items-center gap-2">
                <select
                  value={addInvestorId}
                  onChange={(e) => setAddInvestorId(e.target.value)}
                  className="h-10 min-w-[200px] rounded border border-b-default bg-dark-card px-3 text-sm text-t-primary"
                >
                  <option value="">Seleccionar inversor...</option>
                  {allInvestors
                    .filter((inv) => !investors.some((i) => i.investor_id === String(inv.id)))
                    .map((inv) => (
                      <option key={inv.id} value={inv.id}>{inv.name} ({inv.email})</option>
                    ))}
                </select>
                <button
                  type="button"
                  onClick={handleAddInvestor}
                  disabled={!addInvestorId || addingInvestor}
                  className="h-10 rounded border border-b-default bg-primary px-3 text-sm font-medium text-white hover:bg-primary/90 disabled:opacity-50"
                >
                  {addingInvestor ? "..." : "Agregar"}
                </button>
                <button
                  type="button"
                  onClick={() => { setShowAddInvestor(false); setAddInvestorId(""); }}
                  className="h-10 rounded border border-b-default bg-dark-card px-3 text-sm text-t-muted hover:bg-dark-section"
                >
                  Cancelar
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => setShowAddInvestor(true)}
                className="h-10 rounded border border-b-default bg-dark-card px-3 text-sm text-t-muted hover:bg-dark-section"
              >
                + Agregar inversor
              </button>
            )}
          </div>
        </div>

        {flash ? (
          <div
            data-testid="flash"
            className={
              `mt-4 mb-4 rounded-lg border px-4 py-3 text-sm ` +
              (flash.type === "success"
                ? "border-b-default bg-success/15 text-success"
                : "border-b-default bg-error/15 text-error")
            }
          >
            <div className="flex items-start justify-between gap-3">
              <span className="leading-5">{flash.message}</span>
              <button type="button" onClick={() => setFlash(null)} className="rounded px-2 py-1 text-xs font-medium hover:bg-primary-dim">
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
          const appliedPct = typeof investor.applied_fee_percentage === "number" ? investor.applied_fee_percentage : null;
          const rawPct = percentages[investor.investor_id];
          const pct = isApplied && appliedPct !== null ? appliedPct : rawPct === "" ? null : parseFloat(rawPct ?? "30");
          const pctIsValid = pct !== null && Number.isFinite(pct);
          const feeAmount = investor.has_profit && pctIsValid ? investor.profit_amount * (pct! / 100) : null;
          const shownFeeAmount = isApplied && typeof investor.applied_fee_amount === "number" ? investor.applied_fee_amount : feeAmount;

          return (
            <div key={investor.investor_id} className="rounded-lg border border-b-default bg-dark-card p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold text-t-primary">{investor.investor_name}</div>
                  <div className="truncate text-xs text-t-dim">{investor.investor_email}</div>
                </div>
                <span className="shrink-0 inline-flex rounded-full bg-purple-50 px-2 py-0.5 text-[11px] font-semibold text-purple-800">
                  {freqLabel(investor.trading_fee_frequency)}
                </span>
              </div>

              <div className="mt-3 grid grid-cols-2 gap-3">
                <div>
                  <div className="text-[11px] font-medium uppercase tracking-wide text-t-dim">Período</div>
                  <div className="mt-1 text-sm font-medium text-t-primary">
                    {formatPeriodLabel(investor)}
                    <ClippedBadge inv={investor} />
                  </div>
                  <div className="mt-0.5 text-xs text-t-dim">
                    {formatDate(investor.period_start)} al {formatDate(investor.period_end)}
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-[11px] font-medium uppercase tracking-wide text-t-dim">Rendimientos</div>
                  <div className="mt-1">
                    {investor.has_profit ? (
                      <span className="text-sm font-semibold text-success">{formatCurrencyAR(investor.profit_amount)}</span>
                    ) : (
                      <span className="text-sm text-t-dim">Sin ganancias</span>
                    )}
                  </div>
                  {Array.isArray(investor.monthly_profits) && investor.monthly_profits.length > 0 ? (
                    <button type="button" className="mt-1 inline-flex items-center justify-end gap-1 text-xs text-t-dim hover:text-t-muted" onClick={() => setDetailModal(investor)}>
                      <span>Detalle</span>
                      <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4 text-t-dim" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                        <circle cx="12" cy="12" r="3" />
                      </svg>
                    </button>
                  ) : null}
                </div>
              </div>

              <div className="mt-3 grid grid-cols-2 items-center gap-3">
                <div>
                  <div className="text-[11px] font-medium uppercase tracking-wide text-t-dim">Porcentaje</div>
                  <div className="mt-1 flex items-center gap-2">
                    <input
                      type="number" min="0" max="100" step="0.1"
                      value={isApplied && appliedPct !== null ? String(appliedPct) : (rawPct ?? "30")}
                      onChange={(e) => handlePercentageChange(investor.investor_id, e.target.value)}
                      onWheel={(e) => { e.currentTarget.blur(); }}
                      disabled={!investor.has_profit || isApplied}
                      className="h-9 w-20 rounded border border-b-default px-2 text-sm disabled:bg-dark-section"
                    />
                    <span className="text-sm font-medium text-t-muted">%</span>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-[11px] font-medium uppercase tracking-wide text-t-dim">Comisión</div>
                  <div className="mt-2">
                    {investor.has_profit ? (
                      <span className="text-sm font-semibold text-purple-600">{shownFeeAmount === null ? "—" : formatCurrencyAR(shownFeeAmount)}</span>
                    ) : (
                      <span className="text-sm text-t-dim">—</span>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-4 flex items-center justify-end gap-2">
                {isApplied ? (
                  <>
                    <button type="button" title="Editar" onClick={() => handleEditClick(investor)} className="rounded border border-b-default bg-dark-card p-2 text-t-muted hover:bg-dark-section disabled:opacity-50" disabled={applying}>
                      <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                    </button>
                    <button type="button" title="Eliminar" onClick={() => { if (!investor.applied_fee_id) { setFlash({ type: "error", message: "No se encontró el ID de la comisión aplicada" }); return; } requestDeleteFee(investor.applied_fee_id, investor.investor_name, investor.period_start, investor.period_end); }} className="rounded border border-b-default bg-dark-card p-2 text-error hover:bg-error/15 disabled:opacity-50" disabled={applying}>
                      <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                    </button>
                  </>
                ) : investor.has_profit ? (
                  <button onClick={() => void handleApplyClick(investor)} className="rounded bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700">Aplicar</button>
                ) : (
                  <span className="text-xs text-t-dim">No corresponde</span>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Desktop: table */}
      <div className="hidden md:block overflow-x-auto rounded-lg border border-b-default bg-dark-card">
        <table className="min-w-full divide-y divide-b-default">
          <thead className="bg-dark-section">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-t-muted">Inversor</th>
              <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-t-muted">Período</th>
              <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-t-muted">Rendimientos</th>
              <th className="px-6 py-3 text-center text-xs font-medium uppercase tracking-wider text-t-muted">%</th>
              <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-t-muted">Comisión</th>
              <th className="px-6 py-3 text-center text-xs font-medium uppercase tracking-wider text-t-muted">Acción</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-b-default bg-dark-card">
            {visibleInvestors.map((investor) => {
              const isApplied = !!investor.already_applied;
              const appliedPct = typeof investor.applied_fee_percentage === "number" ? investor.applied_fee_percentage : null;
              const rawPct = percentages[investor.investor_id];
              const pct = isApplied && appliedPct !== null ? appliedPct : rawPct === "" ? null : parseFloat(rawPct ?? "30");
              const pctIsValid = pct !== null && Number.isFinite(pct);
              const feeAmount = investor.has_profit && pctIsValid ? investor.profit_amount * (pct! / 100) : null;
              const shownFeeAmount = isApplied && typeof investor.applied_fee_amount === "number" ? investor.applied_fee_amount : feeAmount;

              return (
                <tr key={investor.investor_id} className="hover:bg-dark-section">
                  <td className="px-6 py-4">
                    <div className="text-sm font-medium text-t-primary">{investor.investor_name}</div>
                    <div className="text-xs text-t-dim">{investor.investor_email}</div>
                    <div className="mt-1">
                      <span className="inline-flex rounded-full bg-purple-50 px-2 py-0.5 text-[11px] font-semibold text-purple-800">{freqLabel(investor.trading_fee_frequency)}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-sm text-t-primary">
                    <div className="font-medium">
                      {formatPeriodLabel(investor)}
                      <ClippedBadge inv={investor} />
                    </div>
                    <div className="text-xs text-t-dim">
                      {formatDate(investor.period_start)} al {formatDate(investor.period_end)}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-right text-sm">
                    <div className="flex flex-col items-end gap-1">
                      {investor.has_profit ? (
                        <span className="font-semibold text-success">{formatCurrencyAR(investor.profit_amount)}</span>
                      ) : (
                        <span className="text-t-dim">Sin ganancias</span>
                      )}
                      {Array.isArray(investor.monthly_profits) && investor.monthly_profits.length > 0 ? (
                        <button type="button" className="inline-flex items-center gap-1 text-xs text-t-dim hover:text-t-muted" onClick={() => setDetailModal(investor)}>
                          <span>Detalle</span>
                          <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4 text-t-dim" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
                            <circle cx="12" cy="12" r="3" />
                          </svg>
                        </button>
                      ) : null}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-center">
                    <input
                      type="number" min="0" max="100" step="0.1"
                      value={isApplied && appliedPct !== null ? String(appliedPct) : (rawPct ?? "30")}
                      onChange={(e) => handlePercentageChange(investor.investor_id, e.target.value)}
                      onWheel={(e) => { e.currentTarget.blur(); }}
                      disabled={!investor.has_profit || isApplied}
                      className="w-20 rounded border border-b-default px-2 py-1 text-center text-sm disabled:bg-dark-section"
                    />
                  </td>
                  <td className="px-6 py-4 text-right">
                    {investor.has_profit ? (
                      <span className="font-semibold text-purple-600">{shownFeeAmount === null ? "—" : formatCurrencyAR(shownFeeAmount)}</span>
                    ) : (
                      <span className="text-t-dim">—</span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-center">
                    {isApplied ? (
                      <div className="flex items-center justify-center gap-2">
                        <button type="button" title="Editar" onClick={() => handleEditClick(investor)} className="rounded border border-b-default bg-dark-card p-2 text-t-muted hover:bg-dark-section disabled:opacity-50" disabled={applying}>
                          <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" /></svg>
                        </button>
                        <button type="button" title="Eliminar" onClick={() => { if (!investor.applied_fee_id) { setFlash({ type: "error", message: "No se encontró el ID de la comisión aplicada" }); return; } requestDeleteFee(investor.applied_fee_id, investor.investor_name, investor.period_start, investor.period_end); }} className="rounded border border-b-default bg-dark-card p-2 text-error hover:bg-error/15 disabled:opacity-50" disabled={applying}>
                          <svg aria-hidden viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                        </button>
                      </div>
                    ) : investor.has_profit ? (
                      <button onClick={() => void handleApplyClick(investor)} className="rounded bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700">Aplicar</button>
                    ) : (
                      <span className="text-xs text-t-dim">No corresponde</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2 text-sm text-t-muted">
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
          <button type="button" className="rounded border border-b-default bg-dark-card px-3 py-2 text-sm text-t-muted hover:bg-dark-section disabled:opacity-50" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>Anterior</button>
          <div className="text-sm text-t-muted">Página <span className="font-semibold">{page}</span> de <span className="font-semibold">{totalPages}</span></div>
          <button type="button" className="rounded border border-b-default bg-dark-card px-3 py-2 text-sm text-t-muted hover:bg-dark-section disabled:opacity-50" disabled={page >= totalPages} onClick={() => setPage((p) => Math.min(totalPages, p + 1))}>Siguiente</button>
        </div>
      </div>

      {/* Detail modal */}
      {detailModal ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black p-4">
          <div className="w-full max-w-lg overflow-hidden rounded-2xl bg-dark-card shadow-2xl">
            <div className="flex items-start justify-between border-b border-b-default px-5 py-4">
              <div>
                <h3 className="text-lg font-semibold text-t-primary">Detalle de rentabilidad</h3>
                <p className="mt-0.5 text-sm text-t-muted">
                  {detailModal.investor_name} · {formatDate(detailModal.period_start)} al {formatDate(detailModal.period_end)}
                </p>
              </div>
              <button type="button" onClick={() => setDetailModal(null)} className="rounded-lg px-3 py-1 text-sm font-medium text-t-muted hover:bg-dark-section">Cerrar</button>
            </div>

            <div className="px-5 py-4">
              {detailModal.withdrawal_fee_in_period ? (
                <div className="mb-4 rounded-xl border border-amber-300/50 bg-amber-50 p-4">
                  <div className="text-sm font-semibold text-amber-800">Fee por retiro cobrado en el período</div>
                  <div className="mt-2 grid grid-cols-2 gap-2 text-sm">
                    <div className="text-amber-700">Fecha del retiro:</div>
                    <div className="text-right font-medium text-amber-900">{formatDate(detailModal.withdrawal_fee_in_period.fee_date)}</div>
                    <div className="text-amber-700">Monto retirado:</div>
                    <div className="text-right font-medium text-amber-900">{formatCurrencyAR(detailModal.withdrawal_fee_in_period.withdrawal_amount)}</div>
                    <div className="text-amber-700">Fee cobrado:</div>
                    <div className="text-right font-medium text-amber-900">{formatCurrencyAR(detailModal.withdrawal_fee_in_period.fee_amount)}</div>
                  </div>
                  {detailModal.period_clipped ? (
                    <p className="mt-2 text-xs text-amber-700">
                      El período fue recortado porque ya se cobró comisión por retiro. Solo se muestran los rendimientos desde el {formatDate(detailModal.period_start)}.
                    </p>
                  ) : null}
                </div>
              ) : null}

              <div className="rounded-xl border border-b-default bg-dark-section p-4">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-t-muted">Total período</span>
                  <span className={(detailModal.profit_amount ?? 0) > 0 ? "text-sm font-semibold text-success" : (detailModal.profit_amount ?? 0) < 0 ? "text-sm font-semibold text-error" : "text-sm font-semibold text-t-muted"}>
                    {formatCurrencyAR(detailModal.profit_amount ?? 0)}
                  </span>
                </div>
              </div>

              <div className="mt-4 overflow-hidden rounded-xl border border-b-default">
                <table className="min-w-full divide-y divide-b-default">
                  <thead className="bg-dark-card">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-t-dim">Mes</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-t-dim">Rendimiento</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-b-default bg-dark-card">
                    {(detailModal.monthly_profits || []).map((mp) => {
                      const amt = Number(mp.amount) || 0;
                      const cls = amt > 0 ? "text-success" : amt < 0 ? "text-error" : "text-t-dim";
                      return (
                        <tr key={mp.month}>
                          <td className="px-4 py-3 text-sm text-t-primary">{formatMonthLabel(mp.month)}</td>
                          <td className={"px-4 py-3 text-right text-sm font-semibold " + cls}>{formatCurrencyAR(amt)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              <div className="mt-4 text-xs text-t-dim">
                Nota: el total del período es la suma de los meses (puede incluir meses negativos).
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {/* Confirm apply modal */}
      {confirmModal ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black p-4">
          <div className="w-full max-w-md rounded-lg bg-dark-card p-6 shadow-xl">
            <h2 className="mb-4 text-xl font-bold text-t-primary">¿Aplicar comisión?</h2>
            <div className="mb-4 space-y-2 rounded-lg border border-purple-600/40 bg-purple-900/25 p-4">
              <div className="flex justify-between"><span className="text-sm text-t-muted">Inversor:</span><span className="text-sm font-semibold text-t-primary">{confirmModal.investor_name}</span></div>
              <div className="flex justify-between"><span className="text-sm text-t-muted">Período:</span><span className="text-sm text-t-primary">{formatDate(confirmModal.period_start)} - {formatDate(confirmModal.period_end)}</span></div>
              <div className="flex justify-between"><span className="text-sm text-t-muted">Ganancias:</span><span className="text-sm font-semibold text-success">{formatCurrencyAR(confirmModal.profit_amount)}</span></div>
              <div className="flex justify-between"><span className="text-sm text-t-muted">Porcentaje:</span><span className="text-sm font-semibold text-t-primary">{confirmModal.fee_percentage}%</span></div>
              <div className="flex justify-between border-t border-purple-600/40 pt-2"><span className="text-sm text-t-muted">Comisión a cobrar:</span><span className="text-lg font-bold text-purple-400">{formatCurrencyAR(confirmModal.fee_amount)}</span></div>
            </div>
            <div className="mb-4 space-y-2">
              <div className="flex justify-between text-sm"><span className="text-t-muted">Capital actual:</span><span className="font-semibold">{formatCurrencyAR(confirmModal.current_balance)}</span></div>
              <div className="flex justify-between text-sm"><span className="text-t-muted">Después de comisión:</span><span className="font-semibold text-success">{formatCurrencyAR(confirmModal.balance_after_fee)}</span></div>
            </div>
            <div className="mb-4">
              <label className="mb-1 block text-sm font-medium text-t-muted">Notas (opcional):</label>
              <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={3} className="w-full rounded border border-b-default px-3 py-2 text-sm" placeholder="Agregar notas..." />
            </div>
            <div className="flex gap-3">
              <button onClick={() => setConfirmModal(null)} disabled={applying} className="flex-1 rounded border border-b-default bg-dark-card px-4 py-2 text-sm font-medium text-t-muted hover:bg-dark-section disabled:opacity-50">Cancelar</button>
              <button onClick={() => void handleConfirmApply()} disabled={applying} className="flex-1 rounded bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50">{applying ? "Aplicando..." : "Confirmar y Aplicar"}</button>
            </div>
          </div>
        </div>
      ) : null}

      {/* Edit modal */}
      {editModal ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black p-4">
          <div className="w-full max-w-md rounded-lg bg-dark-card p-6 shadow-xl">
            <h2 className="mb-4 text-xl font-bold text-t-primary">Editar comisión aplicada</h2>
            {(() => {
              const currentFee = editModal.fee_amount;
              const nextPct = parseFloat(editPercentage || "");
              const nextFee = Number.isNaN(nextPct) ? null : (editModal.profit_amount * (nextPct / 100)).toFixed(2);
              const nextFeeNum = nextFee === null ? null : Number(nextFee);
              const delta = nextFeeNum === null ? null : nextFeeNum - currentFee;
              const balanceAfter = delta === null ? null : editModal.current_balance - delta;
              return (
                <>
                  <div className="mb-4 space-y-2 rounded-lg border border-purple-600/40 bg-purple-900/25 p-4">
                    <div className="flex justify-between"><span className="text-sm text-t-muted">Inversor:</span><span className="text-sm font-semibold text-t-primary">{editModal.investor_name}</span></div>
                    <div className="flex justify-between"><span className="text-sm text-t-muted">Período:</span><span className="text-sm text-t-primary">{formatDate(editModal.period_start)} - {formatDate(editModal.period_end)}</span></div>
                    <div className="flex justify-between"><span className="text-sm text-t-muted">Ganancias:</span><span className="text-sm font-semibold text-success">{formatCurrencyAR(editModal.profit_amount)}</span></div>
                    <div className="flex justify-between"><span className="text-sm text-t-muted">Comisión actual:</span><span className="text-sm font-semibold text-t-primary">{formatCurrencyAR(currentFee)}</span></div>
                  </div>
                  <div className="mb-4">
                    <label className="mb-1 block text-sm font-medium text-t-muted">Nuevo porcentaje</label>
                    <input type="number" min="0" max="100" step="0.1" value={editPercentage} onChange={(e) => setEditPercentage(e.target.value)} onWheel={(e) => { e.currentTarget.blur(); }} className="w-full rounded border border-b-default px-3 py-2 text-sm" />
                    <div className="mt-2 text-sm text-t-muted">Nuevo monto: <span className="font-semibold">{nextFeeNum === null ? "—" : formatCurrencyAR(nextFeeNum)}</span></div>
                    <div className="mt-1 text-sm text-t-muted">Diferencia: <span className="font-semibold">{delta === null ? "—" : formatCurrencyAR(delta)}</span></div>
                    <div className="mt-1 text-sm text-t-muted">Balance después del ajuste: <span className="font-semibold">{balanceAfter === null ? "—" : formatCurrencyAR(balanceAfter)}</span></div>
                    <p className="mt-2 text-xs text-t-dim">Esto no reescribe historia: crea un ajuste contable por la diferencia y actualiza el balance actual.</p>
                  </div>
                  <div className="mb-4">
                    <label className="mb-1 block text-sm font-medium text-t-muted">Notas (opcional)</label>
                    <textarea value={editNotes} onChange={(e) => setEditNotes(e.target.value)} rows={3} className="w-full rounded border border-b-default px-3 py-2 text-sm" placeholder="Agregar notas..." />
                  </div>
                  <div className="flex gap-3">
                    <button onClick={() => setEditModal(null)} disabled={applying} className="flex-1 rounded border border-b-default bg-dark-card px-4 py-2 text-sm font-medium text-t-muted hover:bg-dark-section disabled:opacity-50">Cancelar</button>
                    <button type="button" onClick={() => requestDeleteFee(editModal.applied_fee_id, editModal.investor_name, editModal.period_start, editModal.period_end)} disabled={applying} className="rounded bg-error px-4 py-2 text-sm font-medium text-white hover:bg-error/80 disabled:opacity-50">Eliminar</button>
                    <button onClick={() => void handleConfirmEdit()} disabled={applying} className="flex-1 rounded bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50">{applying ? "Guardando..." : "Guardar"}</button>
                  </div>
                </>
              );
            })()}
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        isOpen={deleteConfirm.open}
        onClose={() => setDeleteConfirm({ open: false, feeId: null, investorName: "", periodStart: "", periodEnd: "" })}
        onConfirm={() => void confirmDeleteFee()}
        title="Eliminar comisión aplicada"
        message={
          <>
            ¿Querés eliminar (anular) la comisión de <span className="font-semibold">{deleteConfirm.investorName}</span>?
            <br /><span className="text-t-muted">Período: {formatDate(deleteConfirm.periodStart)} - {formatDate(deleteConfirm.periodEnd)}</span>
            <br /><span className="text-t-muted">Esto devolverá el monto al balance del inversor.</span>
          </>
        }
        confirmText="Eliminar"
        cancelText="Cancelar"
        confirmVariant="danger"
      />
    </div>
  );
};
