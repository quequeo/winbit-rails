import * as XLSX from "xlsx";
import type { MonthlyReport } from "../types";

function monthToExcelDate(monthKey: string): Date | null {
  const [y, m] = monthKey.split("-").map(Number);
  if (!y || !m) return null;
  return new Date(Date.UTC(y, m - 1, 1, 12, 0, 0));
}

export function buildMonthlyReportWorkbook(report: MonthlyReport): XLSX.WorkBook {
  const wb = XLSX.utils.book_new();

  const summaryRows: (string | number | null)[][] = [
    ["Reporte mensual", report.reportMonth],
    ["Inversor", report.investor.name ?? ""],
    ["Email", report.investor.email ?? ""],
    [],
    ["Valor portafolio (USD)", report.summary.portfolioValueUsd],
    ["Rendimiento mensual Winbit (%)", report.summary.winbitMonthlyReturnPercent],
    ["Acumulado desde ingreso (USD)", report.summary.accumulatedSinceEntryUsd],
    ["Acumulado desde ingreso (%)", report.summary.accumulatedSinceEntryPercent],
    ["Acumulado 2026 (USD)", report.summary.accumulated2026Usd],
    ["Acumulado 2026 (%)", report.summary.accumulated2026Percent],
  ];
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(summaryRows), "Resumen");

  const annexAoa: (string | number | Date | null)[][] = [
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

  let ytdUsd = 0;
  for (const row of report.annexRows) {
    const dateCell = monthToExcelDate(row.month) ?? row.label;
    if (row.openingSnapshot) {
      annexAoa.push([
        dateCell,
        null,
        null,
        row.deposits,
        row.withdrawals,
        row.serviceCost,
        row.portfolioValue,
      ]);
      continue;
    }

    if (row.month.startsWith("2026-")) {
      ytdUsd += row.returnUsd ?? 0;
    }

    const pct =
      row.returnPercent != null ? row.returnPercent / 100 : null;

    annexAoa.push([
      dateCell,
      pct,
      row.returnUsd,
      row.deposits,
      row.withdrawals,
      row.serviceCost,
      row.portfolioValue,
    ]);
  }

  annexAoa.push(["TOTAL", null, ytdUsd, 0, 0, 0, ytdUsd]);

  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(annexAoa), "Anexo");

  return wb;
}

export function downloadMonthlyReportExcel(report: MonthlyReport) {
  const wb = buildMonthlyReportWorkbook(report);
  const safeName = (report.investor.name ?? "inversor")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/\s+/g, "_");
  const filename = `Reporte_${report.reportMonth}_${safeName}.xlsx`;
  XLSX.writeFile(wb, filename);
}
