import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { formatDateAR, formatNumberAR } from "../lib/formatters";
import { DatePicker } from "../components/ui/DatePicker";

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

type EditPreviewInvestorRow = {
  investor_id: string;
  investor_name: string;
  investor_email: string;
  old_delta: number;
  new_delta: number;
  difference: number;
};

type EditPreviewData = {
  date: string;
  old_percent: number;
  new_percent: number;
  investors_count: number;
  total_old_delta: number;
  total_new_delta: number;
  total_difference: number;
  investors: EditPreviewInvestorRow[];
};

const todayISO = () => {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
};

export const DailyOperatingResultsPage = () => {
  const [date, setDate] = useState(todayISO());
  const [percent, setPercent] = useState<string>("0,00");
  const [notes, setNotes] = useState<string>("");
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [applying, setApplying] = useState(false);
  const [notice, setNotice] = useState<{
    type: "success" | "error";
    message: string;
  } | null>(null);
  const [alertOpen, setAlertOpen] = useState(false);
  const [alertTitle, setAlertTitle] = useState<string>("");
  const [alertMessage, setAlertMessage] = useState<string>("");

  type HistoryRow = {
    id: string;
    date: string;
    percent: number;
    applied_by: { name: string | null };
  };
  type HistoryMeta = {
    page: number;
    per_page: number;
    total: number;
    total_pages: number;
  };
  const [historyRows, setHistoryRows] = useState<HistoryRow[]>([]);
  const [historyMeta, setHistoryMeta] = useState<HistoryMeta | null>(null);
  const [historyPage, setHistoryPage] = useState(1);
  const [loadingHistory, setLoadingHistory] = useState(true);

  const [editRow, setEditRow] = useState<HistoryRow | null>(null);
  const [editPercent, setEditPercent] = useState<string>("");
  const [editNotes, setEditNotes] = useState<string>("");
  const [editPreview, setEditPreview] = useState<EditPreviewData | null>(null);
  const [loadingEditPreview, setLoadingEditPreview] = useState(false);
  const [editConfirmOpen, setEditConfirmOpen] = useState(false);
  const [editApplying, setEditApplying] = useState(false);

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

  useEffect(() => {
    loadHistory(historyPage);
  }, [historyPage, loadHistory]);

  const parsedPercent = useMemo(() => {
    const cleaned = percent.replace(/%/g, "").trim();
    if (!cleaned) return null;
    const normalized = cleaned.replace(/\./g, "").replace(/,/g, ".");
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
      showAlert(
        "Fecha inválida",
        "Usá el selector de fecha (formato YYYY-MM-DD).",
      );
      return;
    }
    if (isFutureDate(date)) {
      showAlert(
        "Fecha inválida",
        "No se puede cargar operativa diaria con fecha futura.",
      );
      return;
    }
    if (parsedPercent === null) {
      showAlert(
        "Porcentaje inválido",
        "Ingresá un porcentaje válido (ej: 0,10).",
      );
      return;
    }

    try {
      setLoadingPreview(true);
      setNotice(null);
      const res = await api.previewDailyOperatingResult({
        date,
        percent: parsedPercent,
        notes: notes || undefined,
      });
      setPreview(res?.data as PreviewData);
    } catch (e: unknown) {
      setPreview(null);
      showAlert(
        "No se pudo previsualizar",
        extractErrorMessage(e, "Error al previsualizar"),
      );
    } finally {
      setLoadingPreview(false);
    }
  };

  const apply = async () => {
    if (!preview) return;
    if (parsedPercent === null) return;
    if (preview.investors_count <= 0) {
      showAlert(
        "Sin impacto",
        "No hay inversores activos con capital para esa fecha. No se puede aplicar.",
      );
      return;
    }

    try {
      setApplying(true);
      await api.createDailyOperatingResult({
        date,
        percent: parsedPercent,
        notes: notes || undefined,
      });
      setNotice({ type: "success", message: "Operativa diaria aplicada." });
      setConfirmOpen(false);
      setPreview(null);
      setHistoryPage(1);
      loadHistory(1);
    } catch (e: unknown) {
      showAlert(
        "No se pudo aplicar",
        extractErrorMessage(e, "Error al aplicar"),
      );
    } finally {
      setApplying(false);
    }
  };

  const rows = useMemo(() => {
    if (!preview?.investors) return [];
    return [...preview.investors].sort((a, b) =>
      a.investor_name < b.investor_name ? -1 : 1,
    );
  }, [preview]);
  const canApplyPreview = !!preview && preview.investors_count > 0;

  const openEdit = (row: HistoryRow) => {
    setEditRow(row);
    setEditPercent(row.percent.toFixed(2));
    setEditNotes("");
    setEditPreview(null);
    setEditConfirmOpen(false);
  };

  const closeEdit = () => {
    setEditRow(null);
    setEditPreview(null);
    setEditConfirmOpen(false);
  };

  const editParsedPercent = useMemo(() => {
    const cleaned = editPercent.replace(/%/g, "").trim();
    if (!cleaned) return null;
    const normalized = cleaned.replace(/\./g, "").replace(/,/g, ".");
    const n = Number(normalized);
    return Number.isFinite(n) ? n : null;
  }, [editPercent]);

  const runEditPreview = async () => {
    if (!editRow || editParsedPercent === null) {
      showAlert("Porcentaje inválido", "Ingresá un porcentaje válido.");
      return;
    }
    try {
      setLoadingEditPreview(true);
      const res = await api.editPreviewDailyOperatingResult(editRow.id, {
        percent: editParsedPercent,
      });
      setEditPreview(res?.data as EditPreviewData);
    } catch (e: unknown) {
      setEditPreview(null);
      showAlert(
        "No se pudo previsualizar",
        extractErrorMessage(e, "Error al previsualizar edición"),
      );
    } finally {
      setLoadingEditPreview(false);
    }
  };

  const applyEdit = async () => {
    if (!editRow || editParsedPercent === null) return;
    try {
      setEditApplying(true);
      await api.updateDailyOperatingResult(editRow.id, {
        percent: editParsedPercent,
        notes: editNotes || undefined,
      });
      setNotice({
        type: "success",
        message: "Operativa diaria editada correctamente.",
      });
      closeEdit();
      setHistoryPage(1);
      loadHistory(1);
    } catch (e: unknown) {
      showAlert("No se pudo editar", extractErrorMessage(e, "Error al editar"));
    } finally {
      setEditApplying(false);
    }
  };

  const isToday = (dateStr: string) => dateStr === todayISO();

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-t-primary">Operativa diaria</h1>
          <p className="mt-1 text-sm text-t-muted">
            Cargá el resultado operativo del día (porcentaje). Se aplica a todos
            los inversores activos con capital.
          </p>
        </div>
      </div>

      {notice ? (
        <div
          className={
            `rounded-lg border px-4 py-3 text-sm ` +
            (notice.type === "success"
              ? "border-b-accent bg-success/15 text-success"
              : "border-b-accent bg-error/15 text-error")
          }
        >
          {notice.message}
        </div>
      ) : null}

      <div className="rounded-lg bg-dark-card p-6 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="space-y-2">
            <label className="text-sm font-medium text-t-muted">Fecha</label>
            <DatePicker value={date} onChange={setDate} />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-t-muted">
              Resultado (%)
            </label>
            <Input
              type="text"
              value={percent}
              onChange={(e) => setPercent(e.target.value)}
              placeholder="Ej: 0,10"
            />
            <p className="text-xs text-t-dim">
              Se redondea a 2 decimales en el impacto por inversor.
            </p>
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-t-muted">
              Notas (opcional)
            </label>
            <Input
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder=""
            />
          </div>
        </div>

        <div className="flex gap-3 justify-end">
          <Button
            type="button"
            variant="outline"
            onClick={() => {
              setPreview(null);
            }}
          >
            Limpiar
          </Button>
          <Button
            type="button"
            onClick={() => void runPreview()}
            disabled={loadingPreview}
          >
            {loadingPreview ? "Previsualizando…" : "Previsualizar"}
          </Button>
        </div>
      </div>

      {preview ? (
        <div className="rounded-lg bg-dark-card p-6 space-y-4">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h2 className="text-xl font-bold text-t-primary">Preview</h2>
              <p className="mt-1 text-sm text-t-muted">
                Saldos calculados al cierre del{" "}
                <span className="font-semibold">{preview.date}</span> (18:00
                GMT-3, antes de aplicar la operativa). Si hubo movimientos
                posteriores (depósitos/retiros/trading fees), puede diferir del
                balance actual.
              </p>
              <p className="mt-1 text-sm text-t-muted">
                Inversores impactados:{" "}
                <span className="font-semibold">{preview.investors_count}</span>
              </p>
            </div>
            <Button
              type="button"
              onClick={() => setConfirmOpen(true)}
              disabled={!canApplyPreview}
            >
              Aplicar
            </Button>
          </div>

          {!canApplyPreview ? (
            <div className="rounded-lg border border-b-default bg-warning/15 px-4 py-3 text-sm text-warning">
              No hay inversores activos con capital para esa fecha. No es
              posible aplicar la operativa.
            </div>
          ) : null}

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="rounded-lg border border-b-default bg-dark-section p-4">
              <div className="text-xs uppercase text-t-dim">
                Total antes (cierre)
              </div>
              <div className="mt-1 text-lg font-semibold text-t-primary">
                USD {formatNumberAR(preview.total_before)}
              </div>
            </div>
            <div className="rounded-lg border border-b-default bg-dark-section p-4">
              <div className="text-xs uppercase text-t-dim">Delta total</div>
              <div className="mt-1 text-lg font-semibold text-t-primary">
                USD {formatNumberAR(preview.total_delta)}
              </div>
            </div>
            <div className="rounded-lg border border-b-default bg-dark-section p-4">
              <div className="text-xs uppercase text-t-dim">
                Total después (cierre)
              </div>
              <div className="mt-1 text-lg font-semibold text-t-primary">
                USD {formatNumberAR(preview.total_after)}
              </div>
            </div>
          </div>

          <div className="overflow-hidden rounded-xl border border-b-default">
            <table className="min-w-full divide-y divide-b-default">
              <thead className="bg-dark-section">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-t-muted">
                    Inversor
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-t-muted">
                    Antes (cierre)
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-t-muted">
                    Delta
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-t-muted">
                    Después (cierre)
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-b-default bg-dark-card">
                {rows.map((r) => (
                  <tr key={r.investor_id} className="hover:bg-dark-section">
                    <td className="px-4 py-3 text-sm text-t-primary">
                      <div className="font-medium">{r.investor_name}</div>
                      <div className="text-xs text-t-dim">
                        {r.investor_email}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-t-primary">
                      USD {formatNumberAR(r.balance_before)}
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-t-primary">
                      USD {formatNumberAR(r.delta)}
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-t-primary">
                      USD {formatNumberAR(r.balance_after)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : null}

      {/* Recent history */}
      <div>
        <h2 className="mb-3 text-lg font-semibold text-t-primary">
          Últimas operativas aplicadas
        </h2>

        {loadingHistory ? (
          <div className="py-6 text-center text-sm text-t-dim">
            Cargando...
          </div>
        ) : historyRows.length === 0 ? (
          <div className="py-6 text-center text-sm text-t-dim">
            No hay operativas registradas.
          </div>
        ) : (
          <>
            <div className="overflow-x-auto rounded-lg border border-b-default bg-dark-card-sm">
              <table className="min-w-full divide-y divide-b-default">
                <thead className="bg-dark-section">
                  <tr>
                    <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wider text-t-muted">
                      Fecha
                    </th>
                    <th className="px-5 py-3 text-right text-xs font-semibold uppercase tracking-wider text-t-muted">
                      Rendimiento
                    </th>
                    <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wider text-t-muted">
                      Aplicado por
                    </th>
                    <th className="px-5 py-3 text-center text-xs font-semibold uppercase tracking-wider text-t-muted">
                      Acciones
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-b-default bg-dark-card">
                  {historyRows.map((row) => {
                    const dateStr = formatDateAR(row.date, { time: false });
                    const isPos = row.percent >= 0;
                    const editable = isToday(row.date);
                    return (
                      <tr key={row.id} className="hover:bg-dark-section">
                        <td className="px-5 py-3 text-sm text-t-muted">
                          {dateStr}
                        </td>
                        <td
                          className={`px-5 py-3 text-right text-sm font-semibold ${isPos ? "text-success" : "text-error"}`}
                        >
                          {isPos ? "+" : ""}
                          {row.percent.toFixed(2)}%
                        </td>
                        <td className="px-5 py-3 text-sm text-t-dim">
                          {row.applied_by?.name ?? "—"}
                        </td>
                        <td className="px-5 py-3 text-center">
                          {editable ? (
                            <button
                              type="button"
                              onClick={() => openEdit(row)}
                              className="inline-flex items-center rounded-md border border-b-default bg-dark-card px-2.5 py-1 text-xs font-medium text-t-muted hover:bg-dark-section"
                              title="Editar operativa"
                            >
                              Editar
                            </button>
                          ) : (
                            <span className="text-xs text-t-dim">—</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {historyMeta && historyMeta.total_pages > 1 ? (
              <div className="mt-4 flex items-center justify-between">
                <span className="text-sm text-t-muted">
                  Página{" "}
                  <span className="font-semibold">{historyMeta.page}</span> de{" "}
                  <span className="font-semibold">
                    {historyMeta.total_pages}
                  </span>
                  {" · "}
                  <span className="text-t-dim">
                    {historyMeta.total} registros
                  </span>
                </span>
                <div className="flex gap-2">
                  <button
                    type="button"
                    disabled={historyPage <= 1}
                    onClick={() => setHistoryPage((p) => p - 1)}
                    className="rounded border border-b-default bg-dark-card px-3 py-1.5 text-sm text-t-muted hover:bg-dark-section disabled:opacity-50"
                  >
                    Anterior
                  </button>
                  <button
                    type="button"
                    disabled={historyPage >= historyMeta.total_pages}
                    onClick={() => setHistoryPage((p) => p + 1)}
                    className="rounded border border-b-default bg-dark-card px-3 py-1.5 text-sm text-t-muted hover:bg-dark-section disabled:opacity-50"
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
            <div className="relative w-full max-w-md overflow-hidden rounded-lg bg-dark-card-xl">
              <div className="border-b border-b-default px-6 py-4">
                <h3 className="text-lg font-semibold text-t-primary">
                  {alertTitle || "Error"}
                </h3>
              </div>
              <div className="px-6 py-4">
                <p className="text-sm text-t-muted whitespace-pre-wrap">
                  {alertMessage}
                </p>
              </div>
              <div className="flex justify-end gap-3 border-t border-b-default px-6 py-4">
                <button
                  onClick={() => setAlertOpen(false)}
                  className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/80 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-dark-bg"
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
        message="Esta acción impactará en el capital actual de todos los inversores activos con capital."
        confirmText={applying ? "Aplicando…" : "Confirmar y aplicar"}
        cancelText="Cancelar"
        confirmVariant="primary"
        onConfirm={() => void apply()}
        onClose={() => setConfirmOpen(false)}
      />

      {editRow ? (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div
            className="fixed inset-0 bg-black/15 transition-opacity"
            onClick={closeEdit}
          />
          <div className="flex min-h-full items-center justify-center p-4">
            <div className="relative w-full max-w-2xl overflow-hidden rounded-lg bg-dark-card-xl">
              <div className="border-b border-b-default px-6 py-4">
                <h3 className="text-lg font-semibold text-t-primary">
                  Editar operativa diaria
                </h3>
                <p className="mt-1 text-sm text-t-muted">
                  Fecha: <span className="font-semibold">{editRow.date}</span> —
                  Porcentaje actual:{" "}
                  <span className="font-semibold">
                    {editRow.percent.toFixed(2)}%
                  </span>
                </p>
              </div>
              <div className="px-6 py-4 space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-t-muted">
                      Nuevo porcentaje (%)
                    </label>
                    <Input
                      type="text"
                      value={editPercent}
                      onChange={(e) => setEditPercent(e.target.value)}
                      placeholder="Ej: 0,10"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-medium text-t-muted">
                      Notas (opcional)
                    </label>
                    <Input
                      type="text"
                      value={editNotes}
                      onChange={(e) => setEditNotes(e.target.value)}
                      placeholder=""
                    />
                  </div>
                </div>

                <div className="flex gap-3 justify-end">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => void runEditPreview()}
                    disabled={loadingEditPreview}
                  >
                    {loadingEditPreview
                      ? "Previsualizando…"
                      : "Previsualizar cambio"}
                  </Button>
                </div>

                {editPreview ? (
                  <div className="space-y-3">
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                      <div className="rounded-lg border border-b-default bg-dark-section p-3">
                        <div className="text-xs uppercase text-t-dim">
                          Delta anterior total
                        </div>
                        <div className="mt-1 text-sm font-semibold text-t-primary">
                          USD {formatNumberAR(editPreview.total_old_delta)}
                        </div>
                      </div>
                      <div className="rounded-lg border border-b-default bg-dark-section p-3">
                        <div className="text-xs uppercase text-t-dim">
                          Delta nuevo total
                        </div>
                        <div className="mt-1 text-sm font-semibold text-t-primary">
                          USD {formatNumberAR(editPreview.total_new_delta)}
                        </div>
                      </div>
                      <div className="rounded-lg border border-b-default bg-dark-section p-3">
                        <div className="text-xs uppercase text-t-dim">
                          Diferencia total
                        </div>
                        <div
                          className={`mt-1 text-sm font-semibold ${editPreview.total_difference >= 0 ? "text-success" : "text-error"}`}
                        >
                          USD {formatNumberAR(editPreview.total_difference)}
                        </div>
                      </div>
                    </div>

                    <div className="overflow-hidden rounded-xl border border-b-default max-h-64 overflow-y-auto">
                      <table className="min-w-full divide-y divide-b-default">
                        <thead className="bg-dark-section sticky top-0">
                          <tr>
                            <th className="px-3 py-2 text-left text-xs font-medium uppercase text-t-muted">
                              Inversor
                            </th>
                            <th className="px-3 py-2 text-right text-xs font-medium uppercase text-t-muted">
                              Delta anterior
                            </th>
                            <th className="px-3 py-2 text-right text-xs font-medium uppercase text-t-muted">
                              Delta nuevo
                            </th>
                            <th className="px-3 py-2 text-right text-xs font-medium uppercase text-t-muted">
                              Diferencia
                            </th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-b-default bg-dark-card">
                          {editPreview.investors.map((r) => (
                            <tr
                              key={r.investor_id}
                              className="hover:bg-dark-section"
                            >
                              <td className="px-3 py-2 text-sm text-t-primary">
                                <div className="font-medium">
                                  {r.investor_name}
                                </div>
                                <div className="text-xs text-t-dim">
                                  {r.investor_email}
                                </div>
                              </td>
                              <td className="px-3 py-2 text-right text-sm text-t-primary">
                                USD {formatNumberAR(r.old_delta)}
                              </td>
                              <td className="px-3 py-2 text-right text-sm text-t-primary">
                                USD {formatNumberAR(r.new_delta)}
                              </td>
                              <td
                                className={`px-3 py-2 text-right text-sm font-medium ${r.difference >= 0 ? "text-success" : "text-error"}`}
                              >
                                USD {formatNumberAR(r.difference)}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                ) : null}
              </div>
              <div className="flex justify-end gap-3 border-t border-b-default px-6 py-4">
                <Button type="button" variant="outline" onClick={closeEdit}>
                  Cancelar
                </Button>
                {editPreview ? (
                  <Button
                    type="button"
                    onClick={() => setEditConfirmOpen(true)}
                  >
                    Aplicar cambio
                  </Button>
                ) : null}
              </div>
            </div>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        isOpen={editConfirmOpen}
        title="Confirmar edición de operativa"
        message={`Se cambiará el porcentaje de ${editRow?.percent.toFixed(2)}% a ${editParsedPercent?.toFixed(2)}%. Se recalculará el capital de ${editPreview?.investors_count ?? 0} inversor(es).`}
        confirmText={editApplying ? "Aplicando…" : "Confirmar edición"}
        cancelText="Cancelar"
        confirmVariant="primary"
        onConfirm={() => void applyEdit()}
        onClose={() => setEditConfirmOpen(false)}
      />
    </div>
  );
};
