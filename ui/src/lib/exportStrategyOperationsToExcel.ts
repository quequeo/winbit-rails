import * as XLSX from "xlsx";
import { formatCurrencyAR, formatDateAR, formatNumberAR } from "./formatters";

export type StrategyOperationExportRow = {
  operationDate: string;
  asset: string;
  timeframe?: string | null;
  openedAt?: string | null;
  closedAt?: string | null;
  resultLabel?: string | null;
  resultUsd?: number | null;
  ratio?: number | null;
  direction?: string | null;
  notes?: string | null;
};

export const exportStrategyOperationsToExcel = (
  rows: StrategyOperationExportRow[],
  periodLabel: string,
): void => {
  const sheetRows = rows.map((row) => ({
    Fecha: formatDateAR(row.operationDate, { time: false }),
    Activo: row.asset,
    Temporalidad: row.timeframe || "",
    Apertura: row.openedAt || "",
    Cierre: row.closedAt || "",
    Resultado: row.resultLabel || "",
    USD: row.resultUsd != null ? formatCurrencyAR(row.resultUsd) : "",
    Ratio: row.ratio != null ? formatNumberAR(row.ratio) : "",
    Dirección: row.direction || "",
    Notas: row.notes?.trim() || "",
  }));

  const ws = XLSX.utils.json_to_sheet(sheetRows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Operaciones");

  const safeLabel = periodLabel.replace(/[^\w-]+/g, "_").toLowerCase();
  XLSX.writeFile(wb, `operaciones_estrategia_${safeLabel}.xlsx`);
};
