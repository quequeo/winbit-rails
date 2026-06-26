import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";
import { Select } from "../components/ui/Select";
import {
  exportStrategyOperationsToExcel,
  type StrategyOperationExportRow,
} from "../lib/exportStrategyOperationsToExcel";
import { formatCurrencyAR, formatDateAR, formatNumberAR } from "../lib/formatters";

type StrategyOperation = StrategyOperationExportRow & {
  id: string;
  source: string;
  createdBy?: string | null;
};

const MONTHS = [
  { value: "", label: "Todos los meses" },
  { value: "01", label: "Enero" },
  { value: "02", label: "Febrero" },
  { value: "03", label: "Marzo" },
  { value: "04", label: "Abril" },
  { value: "05", label: "Mayo" },
  { value: "06", label: "Junio" },
  { value: "07", label: "Julio" },
  { value: "08", label: "Agosto" },
  { value: "09", label: "Septiembre" },
  { value: "10", label: "Octubre" },
  { value: "11", label: "Noviembre" },
  { value: "12", label: "Diciembre" },
];

const YEARS = ["2024", "2025", "2026", "2027"];

const emptyForm = {
  operation_date: "",
  asset: "",
  timeframe: "",
  direction: "",
  result_label: "",
  result_usd: "",
  ratio: "",
  opened_at: "",
  closed_at: "",
  notes: "",
};

const periodRange = (year: string, month: string) => {
  if (!year) return { from: undefined, to: undefined, label: "todo" };
  if (!month) {
    return {
      from: `${year}-01-01`,
      to: `${year}-12-31`,
      label: year,
    };
  }
  const lastDay = new Date(Number(year), Number(month), 0).getDate();
  return {
    from: `${year}-${month}-01`,
    to: `${year}-${month}-${String(lastDay).padStart(2, "0")}`,
    label: `${year}-${month}`,
  };
};

export const StrategyOperationsPage = () => {
  const [operations, setOperations] = useState<StrategyOperation[]>([]);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [flash, setFlash] = useState<string | null>(null);
  const [year, setYear] = useState("2026");
  const [month, setMonth] = useState("");
  const [isSuperadmin, setIsSuperadmin] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(emptyForm);

  const range = useMemo(() => periodRange(year, month), [year, month]);

  useEffect(() => {
    api
      .getAdminSession()
      .then((res) => {
        const r = res as { data?: { superadmin?: boolean } };
        setIsSuperadmin(Boolean(r?.data?.superadmin));
      })
      .catch(() => setIsSuperadmin(false));
  }, []);

  const loadOperations = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = (await api.getStrategyOperations({
        from: range.from,
        to: range.to,
        per_page: 200,
      })) as { data?: StrategyOperation[] };
      setOperations(res?.data ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Error al cargar operaciones",
      );
    } finally {
      setLoading(false);
    }
  }, [range.from, range.to]);

  useEffect(() => {
    void loadOperations();
  }, [loadOperations]);

  const handleExport = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = (await api.getStrategyOperations({
        from: range.from,
        to: range.to,
        per_page: 200,
      })) as { data?: StrategyOperation[] };
      const rows = res?.data ?? [];
      if (rows.length === 0) {
        setError("No hay operaciones para exportar en el período seleccionado");
        return;
      }
      exportStrategyOperationsToExcel(rows, range.label);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error al exportar");
    } finally {
      setExporting(false);
    }
  };

  const handleCreate = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      setSaving(true);
      setError(null);
      setFlash(null);
      await api.createStrategyOperation({
        operation_date: form.operation_date,
        asset: form.asset.trim(),
        timeframe: form.timeframe.trim() || undefined,
        direction: form.direction || undefined,
        result_label: form.result_label.trim() || undefined,
        result_usd: form.result_usd ? Number(form.result_usd) : undefined,
        ratio: form.ratio ? Number(form.ratio) : undefined,
        opened_at: form.opened_at.trim() || undefined,
        closed_at: form.closed_at.trim() || undefined,
        notes: form.notes.trim() || undefined,
      });
      setForm(emptyForm);
      setShowForm(false);
      setFlash("Operación cargada correctamente.");
      await loadOperations();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error al guardar");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-t-primary">
            Operaciones de estrategia
          </h2>
          <p className="mt-1 max-w-2xl text-sm text-t-muted">
            Registro detallado por activo. La operativa diaria del admin y la app
            del inversor siguen igual; acá se aloja el detalle de cada trade.
          </p>
        </div>

        <div className="flex flex-wrap items-end gap-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => void handleExport()}
            disabled={exporting || loading}
          >
            {exporting ? "Exportando..." : "Descargar Excel"}
          </Button>
          {isSuperadmin && (
            <Button type="button" onClick={() => setShowForm((v) => !v)}>
              {showForm ? "Cerrar formulario" : "Nueva operación"}
            </Button>
          )}
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:max-w-xl">
        <div>
          <label className="mb-1 block text-xs font-medium text-t-muted">
            Año
          </label>
          <Select
            value={year}
            onChange={(value) => setYear(value)}
            options={[
              { value: "", label: "Todos los años" },
              ...YEARS.map((y) => ({ value: y, label: y })),
            ]}
          />
        </div>
        <div>
          <label className="mb-1 block text-xs font-medium text-t-muted">
            Mes
          </label>
          <Select
            value={month}
            onChange={(value) => setMonth(value)}
            options={MONTHS}
            disabled={!year}
          />
        </div>
      </div>

      <div className="admin-card p-4">
        <p className="text-xs uppercase tracking-wide text-t-dim">Operaciones</p>
        <p className="mt-1 text-2xl font-semibold text-t-primary">
          {operations.length}
        </p>
      </div>

      {flash && <div className="text-sm text-success">{flash}</div>}
      {error && <div className="text-sm text-error">{error}</div>}

      {showForm && isSuperadmin && (
        <form
          onSubmit={(event) => void handleCreate(event)}
          className="admin-card space-y-4 p-5"
        >
          <h3 className="text-sm font-semibold text-t-primary">Nueva operación</h3>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div>
              <label className="mb-1 block text-xs text-t-muted">Fecha</label>
              <Input
                type="date"
                required
                value={form.operation_date}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, operation_date: e.target.value }))
                }
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">Activo</label>
              <Input
                required
                value={form.asset}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, asset: e.target.value }))
                }
                placeholder="NQ, MES, BTC..."
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">
                Temporalidad
              </label>
              <Input
                value={form.timeframe}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, timeframe: e.target.value }))
                }
                placeholder="1m, 2m..."
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">Apertura</label>
              <Input
                value={form.opened_at}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, opened_at: e.target.value }))
                }
                placeholder="12:08"
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">Cierre</label>
              <Input
                value={form.closed_at}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, closed_at: e.target.value }))
                }
                placeholder="12:10"
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">Resultado</label>
              <Input
                value={form.result_label}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, result_label: e.target.value }))
                }
                placeholder="POSITIVO, NEGATIVO, BE+..."
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">USD</label>
              <Input
                type="number"
                step="0.01"
                value={form.result_usd}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, result_usd: e.target.value }))
                }
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">Ratio</label>
              <Input
                type="number"
                step="0.0001"
                value={form.ratio}
                onChange={(e) =>
                  setForm((prev) => ({ ...prev, ratio: e.target.value }))
                }
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-t-muted">Dirección</label>
              <Select
                value={form.direction}
                onChange={(value) =>
                  setForm((prev) => ({ ...prev, direction: value }))
                }
                options={[
                  { value: "", label: "—" },
                  { value: "LONG", label: "LONG" },
                  { value: "SHORT", label: "SHORT" },
                ]}
              />
            </div>
          </div>
          <div>
            <label className="mb-1 block text-xs text-t-muted">Notas</label>
            <textarea
              value={form.notes}
              onChange={(e) =>
                setForm((prev) => ({ ...prev, notes: e.target.value }))
              }
              rows={3}
              className="w-full rounded-md border border-[rgba(101,167,165,0.25)] bg-[#121716] px-3 py-2 text-sm text-white focus:border-primary focus:outline-none"
            />
          </div>
          <div className="flex justify-end">
            <Button type="submit" disabled={saving}>
              {saving ? "Guardando..." : "Guardar operación"}
            </Button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="py-8 text-center text-sm text-t-dim">Cargando...</div>
      ) : operations.length === 0 ? (
        <div className="admin-card py-10 text-center text-sm text-t-dim">
          No hay operaciones para el período seleccionado.
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-b-default bg-dark-card-sm">
          <table className="min-w-full divide-y divide-b-default">
            <thead className="bg-dark-section">
              <tr>
                {[
                  "Fecha",
                  "Activo",
                  "TF",
                  "Apertura",
                  "Cierre",
                  "Resultado",
                  "USD",
                  "Ratio",
                  "L/S",
                  "Notas",
                ].map((label) => (
                  <th
                    key={label}
                    className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-t-muted"
                  >
                    {label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-b-default bg-dark-card">
              {operations.map((row) => (
                <tr key={row.id} className="hover:bg-dark-section">
                  <td className="px-4 py-3 text-sm text-t-muted">
                    {formatDateAR(row.operationDate, { time: false })}
                  </td>
                  <td className="px-4 py-3 text-sm font-semibold text-t-primary">
                    {row.asset}
                  </td>
                  <td className="px-4 py-3 text-sm text-t-muted">
                    {row.timeframe || "—"}
                  </td>
                  <td className="px-4 py-3 text-sm text-t-muted">
                    {row.openedAt || "—"}
                  </td>
                  <td className="px-4 py-3 text-sm text-t-muted">
                    {row.closedAt || "—"}
                  </td>
                  <td className="px-4 py-3 text-sm text-t-muted">
                    {row.resultLabel || "—"}
                  </td>
                  <td className="px-4 py-3 text-right text-sm text-t-primary">
                    {row.resultUsd != null ? formatCurrencyAR(row.resultUsd) : "—"}
                  </td>
                  <td className="px-4 py-3 text-right text-sm text-t-muted">
                    {row.ratio != null ? formatNumberAR(row.ratio) : "—"}
                  </td>
                  <td className="px-4 py-3 text-sm text-t-muted">
                    {row.direction || "—"}
                  </td>
                  <td className="max-w-md px-4 py-3 text-sm text-t-dim">
                    {row.notes || "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
