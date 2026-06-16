import * as XLSX from "xlsx";
import { formatCurrencyAR, formatDateAR, formatNumberAR } from "./formatters";

export type OperatingExportRow = {
  date: string;
  percent: number;
  amount_usd: number;
  notes?: string | null;
};

export const exportOperatingToExcel = (rows: OperatingExportRow[]): void => {
  const sheetRows = rows.map((row) => ({
    Fecha: formatDateAR(row.date, { time: false }),
    "Resultado (%)": formatNumberAR(row.percent),
    "Resultado (USD)": formatCurrencyAR(row.amount_usd),
    Notas: row.notes?.trim() || "",
  }));

  const ws = XLSX.utils.json_to_sheet(sheetRows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Operativas");

  const dateStr = new Date().toISOString().slice(0, 10);
  XLSX.writeFile(wb, `operativas_${dateStr}.xlsx`);
};
