import * as XLSX from "xlsx-js-style";
import type { MonthlyReport } from "../types";

const USD_FORMAT = "#,##0";
const USD_FORMAT_CENTS = "#,##0.00";
const PCT_FORMAT = "0.0%";
const PCT_FORMAT_RESUMEN = "0.00%";

function roundUsdTwoDec(value: number | null | undefined): number | null {
  if (value == null || !Number.isFinite(value)) return null;
  return Math.round(value * 100) / 100;
}

function pctToDecimalTwoDec(
  valuePercentPoints: number | null | undefined,
): number | null {
  if (valuePercentPoints == null || !Number.isFinite(valuePercentPoints)) {
    return null;
  }
  const twoDec = Math.round(valuePercentPoints * 100) / 100;
  return Number((twoDec / 100).toFixed(6));
}

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

function applyUsdFormat(
  ws: XLSX.WorkSheet,
  ref: string,
  format: string = USD_FORMAT,
) {
  const cell = ws[ref];
  if (cell && typeof cell.v === "number") {
    cell.z = format;
  }
}

function applyPctFormat(
  ws: XLSX.WorkSheet,
  ref: string,
  format: string = PCT_FORMAT,
) {
  const cell = ws[ref];
  if (cell && typeof cell.v === "number") {
    cell.z = format;
  }
}

function buildSummarySheet(report: MonthlyReport): XLSX.WorkSheet {
  const s = report.summary;
  const ws = XLSX.utils.aoa_to_sheet([
    ["Reporte mensual", report.reportMonth],
    ["Inversor", report.investor.name ?? ""],
    ["Email", report.investor.email ?? ""],
    ["", ""],
    ["Valor portafolio (USD)", cellValue(roundUsdTwoDec(s.portfolioValueUsd))],
    [
      "Rendimiento mensual Winbit (%)",
      cellValue(pctToDecimalOneDec(s.winbitMonthlyReturnPercent)),
    ],
    [
      "Acumulado desde ingreso (USD)",
      cellValue(roundUsdTwoDec(s.accumulatedSinceEntryUsd)),
    ],
    [
      "Acumulado desde ingreso (%)",
      cellValue(pctToDecimalTwoDec(s.accumulatedSinceEntryPercent)),
    ],
    ["Acumulado 2026 (USD)", cellValue(roundUsdTwoDec(s.accumulated2026Usd))],
    [
      "Acumulado 2026 (%)",
      cellValue(pctToDecimalTwoDec(s.accumulated2026Percent)),
    ],
  ]);

  applyUsdFormat(ws, "B5", USD_FORMAT_CENTS);
  applyPctFormat(ws, "B6", PCT_FORMAT);
  applyUsdFormat(ws, "B7", USD_FORMAT_CENTS);
  applyPctFormat(ws, "B8", PCT_FORMAT_RESUMEN);
  applyUsdFormat(ws, "B9", USD_FORMAT_CENTS);
  applyPctFormat(ws, "B10", PCT_FORMAT_RESUMEN);

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

  const rowsForTotals = report.annexRows.filter(
    (row) => !row.openingSnapshot && !row.entryRow,
  );
  const totalReturnUsd = rowsForTotals.reduce(
    (acc, row) => acc + (row.returnUsd ?? 0),
    0,
  );
  const totalDeposits = rowsForTotals.reduce(
    (acc, row) => acc + (row.deposits ?? 0),
    0,
  );
  const totalWithdrawals = rowsForTotals.reduce(
    (acc, row) => acc + (row.withdrawals ?? 0),
    0,
  );
  const totalCst = rowsForTotals.reduce(
    (acc, row) => acc + (row.serviceCost ?? 0),
    0,
  );
  const openingRow = report.annexRows.find(
    (row) => row.openingSnapshot || row.entryRow,
  );
  const openingValue = openingRow?.portfolioValue ?? 0;
  const portfolioDelta =
    closingValue != null && Number.isFinite(closingValue)
      ? closingValue - openingValue
      : null;

  blockRows.push([
    "TOTAL",
    "",
    cellValue(roundUsd(totalReturnUsd)),
    cellValue(roundUsd(totalDeposits)),
    cellValue(roundUsd(totalWithdrawals)),
    cellValue(roundUsd(totalCst)),
    cellValue(roundUsd(portfolioDelta)),
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
      cellValue(roundUsdTwoDec(s.portfolioValueUsd)),
      cellValue(pctToDecimalOneDec(s.winbitMonthlyReturnPercent)),
      cellValue(roundUsdTwoDec(s.accumulatedSinceEntryUsd)),
      cellValue(pctToDecimalTwoDec(s.accumulatedSinceEntryPercent)),
      cellValue(roundUsdTwoDec(s.accumulated2026Usd)),
      cellValue(pctToDecimalTwoDec(s.accumulated2026Percent)),
    ];
  });

  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);

  for (let r = 1; r <= rows.length; r += 1) {
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 2 }), USD_FORMAT_CENTS);
    applyPctFormat(ws, XLSX.utils.encode_cell({ r, c: 3 }), PCT_FORMAT);
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 4 }), USD_FORMAT_CENTS);
    applyPctFormat(ws, XLSX.utils.encode_cell({ r, c: 5 }), PCT_FORMAT_RESUMEN);
    applyUsdFormat(ws, XLSX.utils.encode_cell({ r, c: 6 }), USD_FORMAT_CENTS);
    applyPctFormat(ws, XLSX.utils.encode_cell({ r, c: 7 }), PCT_FORMAT_RESUMEN);
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

export { roundUsd, roundUsdTwoDec, pctToDecimalOneDec, pctToDecimalTwoDec, USD_FORMAT, USD_FORMAT_CENTS, PCT_FORMAT, PCT_FORMAT_RESUMEN };
