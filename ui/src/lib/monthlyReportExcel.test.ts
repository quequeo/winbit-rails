import { describe, it, expect, vi, beforeEach } from "vitest";
import * as XLSX from "xlsx";
import { buildMonthlyReportWorkbook } from "./monthlyReportExcel";
import type { MonthlyReport } from "../types";

describe("monthlyReportExcel", () => {
  const sampleReport: MonthlyReport = {
    investor: { id: "1", name: "Eugenio Carrió", email: "eugenio@test.com" },
    reportMonth: "2026-05",
    summary: {
      portfolioValueUsd: 6750.04,
      winbitMonthlyReturnPercent: -1.78,
      accumulatedSinceEntryUsd: 2322.75,
      accumulatedSinceEntryPercent: 42.21,
      accumulated2026Usd: 323.75,
      accumulated2026Percent: 5.36,
    },
    annexRows: [
      {
        month: "2025-12",
        label: "Dec-25",
        returnPercent: null,
        returnUsd: null,
        deposits: 0,
        withdrawals: 0,
        serviceCost: 0,
        portfolioValue: 6044,
        openingSnapshot: true,
        source: "spreadsheet",
      },
      {
        month: "2026-05",
        label: "May-26",
        returnPercent: -1.79,
        returnUsd: -116.25,
        deposits: 382.29,
        withdrawals: 0,
        serviceCost: 0,
        portfolioValue: 6750.04,
        openingSnapshot: false,
        source: "platform",
      },
    ],
  };

  it("builds workbook with Resumen and Anexo sheets", () => {
    const wb = buildMonthlyReportWorkbook(sampleReport);
    expect(wb.SheetNames).toEqual(["Resumen", "Anexo"]);

    const resumen = XLSX.utils.sheet_to_json<string[]>(wb.Sheets.Resumen, {
      header: 1,
    });
    expect(resumen[0]).toEqual(["Reporte mensual", "2026-05"]);
    expect(resumen[1]).toEqual(["Inversor", "Eugenio Carrió"]);

    const anexo = XLSX.utils.sheet_to_json<string[]>(wb.Sheets.Anexo, {
      header: 1,
    });
    expect(anexo[0][0]).toBe("EUGENIO CARRIÓ");
    expect(anexo[anexo.length - 1][0]).toBe("TOTAL");
  });
});
