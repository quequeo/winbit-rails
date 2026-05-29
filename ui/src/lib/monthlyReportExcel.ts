import * as XLSX from "xlsx-js-style";
import type { MonthlyReport } from "../types";

const USD_FORMAT = "#,##0";
const PCT_FORMAT = "0.0%";

type CellValue = string | number | Date | null;

function monthToExcelDate(monthKey: string): Date | null {
  const [y, m] = monthKey.split("-").map(Number);
  if (!y || !m) return null;
  return new Date(Date.UTC(y, m - 1, 1, 12, 0, 0));
}

function roundUsd(value: number | null | undefined): number | null {
  if (value == null || !Number.isFinite(value)) return null;
  return Math.round(value);
}

function pctToDecimalOneDec(
  valuePercentPoints: number | null | undefined,
): number | null {
  if (valuePercentPoints == null || !Number.isFinite(valuePercentPoints)) {
    return null;
  }
  const oneDec = Math.round(valuePercentPoints * 10) / 10;
  return Number((oneDec / 100).toFixed(4));
}

function setCell(
  ws: XLSX.WorkSheet,
  row: number,
  col: number,
  value: CellValue,
) {
  if (value == null || value === "") return;
  const ref = XLSX.utils.encode_cell({ r: row, c: col });
  if (value instanceof Date) {
    ws[ref] = { t: "d", v: value };
    return;
  }
  if (typeof value === "number") {
    ws[ref] = { t: "n", v: value };
    return;
  }
  ws[ref] = { t: "s", v: String(value) };
}

function setUsdCell(
  ws: XLSX.WorkSheet,
  row: number,
  col: number,
  value: number | null | undefined,
) {
  const rounded = roundUsd(value);
  if (rounded == null) return;
  const ref = XLSX.utils.encode_cell({ r: row, c: col });
  ws[ref] = { t: "n", v: rounded, z: USD_FORMAT };
}

function setPctCell(
  ws: XLSX.WorkSheet,
  row: number,
  col: number,
  valuePercentPoints: number | null | undefined,
) {
  const decimal = pctToDecimalOneDec(valuePercentPoints);
  if (decimal == null) return;
  const ref = XLSX.utils.encode_cell({ r: row, c: col });
  ws[ref] = { t: "n", v: decimal, z: PCT_FORMAT };
}

function updateSheetRange(ws: XLSX.WorkSheet, row: number, col: number) {
  const ref = XLSX.utils.encode_cell({ r: row, c: col });
  if (!ws["!ref"]) {
    ws["!ref"] = ref;
    return;
  }
  const range = XLSX.utils.decode_range(ws["!ref"]);
  if (row > range.e.r) range.e.r = row;
  if (col > range.e.c) range.e.c = col;
  ws["!ref"] = XLSX.utils.encode_range(range);
}

function appendSummaryRows(ws: XLSX.WorkSheet, report: MonthlyReport, startRow: number) {
  const rows: [string, CellValue][] = [
    ["Reporte mensual", report.reportMonth],
    ["Inversor", report.investor.name ?? ""],
    ["Email", report.investor.email ?? ""],
    ["", ""],
    ["Valor portafolio (USD)", null],
    ["Rendimiento mensual Winbit (%)", null],
    ["Acumulado desde ingreso (USD)", null],
    ["Acumulado desde ingreso (%)", null],
    ["Acumulado 2026 (USD)", null],
    ["Acumulado 2026 (%)", null],
  ];

  rows.forEach((row, idx) => {
    const r = startRow + idx;
    setCell(ws, r, 0, row[0]);
    if (row[1] != null) setCell(ws, r, 1, row[1]);
    updateSheetRange(ws, r, 1);
  });

  const s = report.summary;
  const valueRow = startRow + 4;
  setUsdCell(ws, valueRow, 1, s.portfolioValueUsd);
  setPctCell(ws, valueRow + 1, 1, s.winbitMonthlyReturnPercent);
  setUsdCell(ws, valueRow + 2, 1, s.accumulatedSinceEntryUsd);
  setPctCell(ws, valueRow + 3, 1, s.accumulatedSinceEntryPercent);
  setUsdCell(ws, valueRow + 4, 1, s.accumulated2026Usd);
  setPctCell(ws, valueRow + 5, 1, s.accumulated2026Percent);
  updateSheetRange(ws, valueRow + 5, 1);

  return startRow + rows.length;
}

function appendAnnexBlock(
  ws: XLSX.WorkSheet,
  report: MonthlyReport,
  startRow: number,
): number {
  let row = startRow;

  setCell(ws, row, 0, (report.investor.name ?? "").toUpperCase());
  setCell(ws, row, 1, "RDO M %");
  setCell(ws, row, 2, "RDO M $");
  setCell(ws, row, 3, "INGRESOS");
  setCell(ws, row, 4, "RETIROS");
  setCell(ws, row, 5, "CST");
  setCell(ws, row, 6, "VALOR PORTAFOLIO");
  updateSheetRange(ws, row, 6);
  row += 1;

  let ytdUsd = 0;

  for (const annexRow of report.annexRows) {
    const firstCol =
      annexRow.entryRow || annexRow.label === "INGRESO"
        ? "INGRESO"
        : monthToExcelDate(annexRow.month) ?? annexRow.label;
    setCell(ws, row, 0, firstCol);

    if (annexRow.openingSnapshot || annexRow.entryRow) {
      setUsdCell(ws, row, 3, annexRow.deposits ?? 0);
      setUsdCell(ws, row, 4, annexRow.withdrawals ?? 0);
      setUsdCell(ws, row, 5, annexRow.serviceCost ?? 0);
      setUsdCell(ws, row, 6, annexRow.portfolioValue);
    } else {
      setPctCell(ws, row, 1, annexRow.returnPercent);
      setUsdCell(ws, row, 2, annexRow.returnUsd);
      setUsdCell(ws, row, 3, annexRow.deposits ?? 0);
      setUsdCell(ws, row, 4, annexRow.withdrawals ?? 0);
      setUsdCell(ws, row, 5, annexRow.serviceCost ?? 0);
      setUsdCell(ws, row, 6, annexRow.portfolioValue);

      if (annexRow.month.startsWith("2026-")) {
        ytdUsd += annexRow.returnUsd ?? 0;
      }
    }

    updateSheetRange(ws, row, 6);
    row += 1;
  }

  setCell(ws, row, 0, "TOTAL");
  setUsdCell(ws, row, 2, ytdUsd);
  setUsdCell(ws, row, 3, 0);
  setUsdCell(ws, row, 4, 0);
  setUsdCell(ws, row, 5, 0);
  setUsdCell(ws, row, 6, ytdUsd);
  updateSheetRange(ws, row, 6);

  return row + 1;
}

function buildResumenTableSheet(reports: MonthlyReport[]): XLSX.WorkSheet {
  const ws: XLSX.WorkSheet = {};
  const headers = [
    "Inversor",
    "Email",
    "Valor portafolio (USD)",
    "Rendimiento mensual Winbit (%)",
    "Acumulado desde ingreso (USD)",
    "Acumulado desde ingreso (%)",
    "Acumulado 2026 (USD)",
    "Acumulado 2026 (%)",
  ];

  headers.forEach((header, col) => {
    setCell(ws, 0, col, header);
  });
  updateSheetRange(ws, 0, headers.length - 1);

  reports.forEach((report, idx) => {
    const row = idx + 1;
    const s = report.summary;
    setCell(ws, row, 0, report.investor.name ?? "");
    setCell(ws, row, 1, report.investor.email ?? "");
    setUsdCell(ws, row, 2, s.portfolioValueUsd);
    setPctCell(ws, row, 3, s.winbitMonthlyReturnPercent);
    setUsdCell(ws, row, 4, s.accumulatedSinceEntryUsd);
    setPctCell(ws, row, 5, s.accumulatedSinceEntryPercent);
    setUsdCell(ws, row, 6, s.accumulated2026Usd);
    setPctCell(ws, row, 7, s.accumulated2026Percent);
    updateSheetRange(ws, row, headers.length - 1);
  });

  return ws;
}

export function buildMonthlyReportWorkbook(report: MonthlyReport): XLSX.WorkBook {
  const wb = XLSX.utils.book_new();

  const resumenWs: XLSX.WorkSheet = {};
  appendSummaryRows(resumenWs, report, 0);
  XLSX.utils.book_append_sheet(wb, resumenWs, "Resumen");

  const annexWs: XLSX.WorkSheet = {};
  appendAnnexBlock(annexWs, report, 0);
  XLSX.utils.book_append_sheet(wb, annexWs, "Anexo");

  return wb;
}

export function buildAllInvestorsWorkbook(reports: MonthlyReport[]): XLSX.WorkBook {
  const wb = XLSX.utils.book_new();
  const sorted = [...reports].sort((a, b) =>
    (a.investor.name ?? "").localeCompare(b.investor.name ?? "", "es"),
  );

  XLSX.utils.book_append_sheet(wb, buildResumenTableSheet(sorted), "Resumen");

  const annexWs: XLSX.WorkSheet = {};
  let row = 0;
  sorted.forEach((report, idx) => {
    row = appendAnnexBlock(annexWs, report, row);
    if (idx < sorted.length - 1) {
      row += 1;
    }
  });
  XLSX.utils.book_append_sheet(wb, annexWs, "Anexo");

  return wb;
}

function safeFilenamePart(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/\s+/g, "_");
}

export function downloadMonthlyReportExcel(report: MonthlyReport) {
  const wb = buildMonthlyReportWorkbook(report);
  const safeName = safeFilenamePart(report.investor.name ?? "inversor");
  XLSX.writeFile(wb, `Reporte_${report.reportMonth}_${safeName}.xlsx`);
}

export function downloadAllInvestorsReportsExcel(
  reports: MonthlyReport[],
  reportMonth: string,
) {
  const wb = buildAllInvestorsWorkbook(reports);
  XLSX.writeFile(wb, `Reporte_${reportMonth}_todos_los_inversores.xlsx`);
}

export { roundUsd, pctToDecimalOneDec, USD_FORMAT, PCT_FORMAT };
