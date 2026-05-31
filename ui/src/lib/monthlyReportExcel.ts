import * as XLSX from "xlsx-js-style";
import type { MonthlyReport } from "../types";

const USD_FORMAT = "#,##0";
const PCT_FORMAT = "0.0%";

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

function cellValue(value: string | number | Date | null | undefined) {
  if (value == null) return "";
  return value;
}

function applyUsdFormat(ws: XLSX.WorkSheet, ref: string) {
  const cell = ws[ref];
  if (cell && typeof cell.v === "number") {
    cell.z = USD_FORMAT;
  }
}

function applyPctFormat(ws: XLSX.WorkSheet, ref: string) {
  const cell = ws[ref];
  if (cell && typeof cell.v === "number") {
    cell.z = PCT_FORMAT;
  }
}

function buildSummarySheet(report: MonthlyReport): XLSX.WorkSheet {
  const s = report.summary;
  const ws = XLSX.utils.aoa_to_sheet([
    ["Reporte mensual", report.reportMonth],
    ["Inversor", report.investor.name ?? ""],
    ["Email", report.investor.email ?? ""],
    ["", ""],
    ["Valor portafolio (USD)", cellValue(roundUsd(s.portfolioValueUsd))],
    [
      "Rendimiento mensual Winbit (%)",
      cellValue(pctToDecimalOneDec(s.winbitMonthlyReturnPercent)),
    ],
    [
      "Acumulado desde ingreso (USD)",
      cellValue(roundUsd(s.accumulatedSinceEntryUsd)),
    ],
    [
      "Acumulado desde ingreso (%)",
      cellValue(pctToDecimalOneDec(s.accumulatedSinceEntryPercent)),
    ],
    ["Acumulado 2026 (USD)", cellValue(roundUsd(s.accumulated2026Usd))],
    [
      "Acumulado 2026 (%)",
      cellValue(pctToDecimalOneDec(s.accumulated2026Percent)),
    ],
  ]);

  applyUsdFormat(ws, "B5");
  applyPctFormat(ws, "B6");
  applyUsdFormat(ws, "B7");
  applyPctFormat(ws, "B8");
  applyUsdFormat(ws, "B9");
  applyPctFormat(ws, "B10");

  ws["!cols"] = [{ wch: 34 }, { wch: 20 }];

  return ws;
}

function appendAnnexBlock(
  ws: XLSX.WorkSheet,
  report: MonthlyReport,
  startRow: number,
): number {
  const blockRows: (string | number | Date)[][] = [
    [
      (report.investor.name ?? "").toUpperCase(),
      "RDO M %",
      "RDO M $",
      "INGRESOS",
      "RETIROS",
      "CST",
      "VALOR PORTAFOLIO",
    ],
  ];

  const ytdUsd = report.summary.accumulated2026Usd;
  const closingValue = report.summary.portfolioValueUsd;

  for (const annexRow of report.annexRows) {
    const firstCol =
      annexRow.entryRow || annexRow.label === "INGRESO"
        ? "INGRESO"
        : monthToExcelDate(annexRow.month) ?? annexRow.label;

    if (annexRow.openingSnapshot || annexRow.entryRow) {
      blockRows.push([
        firstCol,
        "",
        "",
        cellValue(roundUsd(annexRow.deposits ?? 0)),
        cellValue(roundUsd(annexRow.withdrawals ?? 0)),
        cellValue(roundUsd(annexRow.serviceCost ?? 0)),
        cellValue(roundUsd(annexRow.portfolioValue)),
      ]);
    } else {
      blockRows.push([
        firstCol,
        cellValue(pctToDecimalOneDec(annexRow.returnPercent)),
        cellValue(roundUsd(annexRow.returnUsd)),
        cellValue(roundUsd(annexRow.deposits ?? 0)),
        cellValue(roundUsd(annexRow.withdrawals ?? 0)),
        cellValue(roundUsd(annexRow.serviceCost ?? 0)),
        cellValue(roundUsd(annexRow.portfolioValue)),
      ]);
    }
  }

  blockRows.push([
    "TOTAL",
    "",
    cellValue(roundUsd(ytdUsd)),
    0,
    0,
    0,
    cellValue(roundUsd(closingValue)),
  ]);

  XLSX.utils.sheet_add_aoa(ws, blockRows, { origin: { r: startRow, c: 0 } });

  const endRow = startRow + blockRows.length - 1;
  for (let r = startRow + 1; r <= endRow; r += 1) {
    applyPctFormat(ws, XLSX.utils.encode_cell({ r, c: 1 }));
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 2 }));
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 3 }));
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 4 }));
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 5 }));
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 6 }));
  }

  return endRow + 1;
}

function buildResumenTableSheet(reports: MonthlyReport[]): XLSX.WorkSheet {
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

  const rows = reports.map((report) => {
    const s = report.summary;
    return [
      report.investor.name ?? "",
      report.investor.email ?? "",
      cellValue(roundUsd(s.portfolioValueUsd)),
      cellValue(pctToDecimalOneDec(s.winbitMonthlyReturnPercent)),
      cellValue(roundUsd(s.accumulatedSinceEntryUsd)),
      cellValue(pctToDecimalOneDec(s.accumulatedSinceEntryPercent)),
      cellValue(roundUsd(s.accumulated2026Usd)),
      cellValue(pctToDecimalOneDec(s.accumulated2026Percent)),
    ];
  });

  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);

  for (let r = 1; r <= rows.length; r += 1) {
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 2 }));
    applyPctFormat(ws, XLSX.utils.encode_cell({ r, c: 3 }));
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 4 }));
    applyPctFormat(ws, XLSX.utils.encode_cell({ r, c: 5 }));
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 6 }));
    applyPctFormat(ws, XLSX.utils.encode_cell({ r, c: 7 }));
  }

  ws["!cols"] = [
    { wch: 24 },
    { wch: 28 },
    { wch: 16 },
    { wch: 18 },
    { wch: 18 },
    { wch: 18 },
    { wch: 16 },
    { wch: 16 },
  ];

  return ws;
}

export function buildMonthlyReportWorkbook(report: MonthlyReport): XLSX.WorkBook {
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, buildSummarySheet(report), "Resumen");

  const annexWs: XLSX.WorkSheet = {};
  appendAnnexBlock(annexWs, report, 0);
  annexWs["!cols"] = [
    { wch: 14 },
    { wch: 10 },
    { wch: 10 },
    { wch: 10 },
    { wch: 10 },
    { wch: 8 },
    { wch: 16 },
  ];
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
  annexWs["!cols"] = [
    { wch: 14 },
    { wch: 10 },
    { wch: 10 },
    { wch: 10 },
    { wch: 10 },
    { wch: 8 },
    { wch: 16 },
  ];
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
