import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { Button } from "../components/ui/Button";
import { Select } from "../components/ui/Select";
import {
  exportStrategyOperationsToExcel,
  type StrategyOperationExportRow,
} from "../lib/exportStrategyOperationsToExcel";
import { formatStrategyOperationTime } from "../lib/formatStrategyOperationTime";
import { formatCurrencyAR, formatDateAR, formatNumberAR } from "../lib/formatters";
import {
  strategyOperationTone,
  strategyOperationToneClass,
} from "../lib/strategyOperationTone";

type StrategyOperation = StrategyOperationExportRow & {
  id: string;
  source: string;
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
  const [error, setError] = useState<string | null>(null);
  const [year, setYear] = useState("2026");
  const [month, setMonth] = useState("");

  const range = useMemo(() => periodRange(year, month), [year, month]);

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

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-t-primary">
            Operaciones de estrategia
          </h2>
          <p className="mt-1 max-w-2xl text-sm text-t-muted">
            Detalle por activo cargado desde Operativa diaria. Los inversores
            siguen viendo solo la rentabilidad diaria consolidada.
          </p>
        </div>

        <Button
          type="button"
          variant="outline"
          onClick={() => void handleExport()}
          disabled={exporting || loading}
        >
          {exporting ? "Exportando..." : "Descargar Excel"}
        </Button>
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

      {error && <div className="text-sm text-error">{error}</div>}

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
              {operations.map((row) => {
                const tone = strategyOperationTone(row);
                const toneClass = strategyOperationToneClass(tone);
                return (
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
                      {formatStrategyOperationTime(row.openedAt)}
                    </td>
                    <td className="px-4 py-3 text-sm text-t-muted">
                      {formatStrategyOperationTime(row.closedAt)}
                    </td>
                    <td className={`px-4 py-3 text-sm font-semibold ${toneClass}`}>
                      {row.resultLabel || "—"}
                    </td>
                    <td className={`px-4 py-3 text-right text-sm font-semibold ${toneClass}`}>
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
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
