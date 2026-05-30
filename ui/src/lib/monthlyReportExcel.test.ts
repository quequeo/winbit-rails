import { describe, it, expect } from "vitest";
import * as XLSX from "xlsx-js-style";
import {
  buildMonthlyReportWorkbook,
  buildAllInvestorsWorkbook,
  pctToDecimalOneDec,
  roundUsd,
  PCT_FORMAT,
  USD_FORMAT,
} from "./monthlyReportExcel";
import type { MonthlyReport } from "../types";

const sampleReport: MonthlyReport = {
  investor: { id: "1", name: "Marcela Manavella", email: "mmarcela724@gmail.com" },
  reportMonth: "2026-05",
  summary: {
    portfolioValueUsd: 553.2,
    winbitMonthlyReturnPercent: -1.78,
    accumulatedSinceEntryUsd: null,
    accumulatedSinceEntryPercent: null,
    accumulated2026Usd: 0,
    accumulated2026Percent: 0,
  },
  annexRows: [
    {
      month: "2026-04",
      label: "INGRESO",
      returnPercent: null,
      returnUsd: null,
      deposits: 0,
      withdrawals: 0,
      serviceCost: 0,
      portfolioValue: 500,
      openingSnapshot: true,
      entryRow: true,
      source: "spreadsheet",
    },
    {
      month: "2026-05",
      label: "May-26",
      returnPercent: -1.8,
      returnUsd: 0,
      deposits: 0,
      withdrawals: 0,
      serviceCost: 0,
      portfolioValue: 553,
      openingSnapshot: false,
      source: "platform",
    },
  ],
};

describe("monthlyReportExcel formatting helpers", () => {
  it("rounds USD to integers", () => {
    expect(roundUsd(6750.04)).toBe(6750);
    expect(roundUsd(-116.25)).toBe(-116);
  });

  it("converts percent points to one-decimal Excel decimal", () => {
    expect(pctToDecimalOneDec(-1.78)).toBe(-0.018);
    expect(pctToDecimalOneDec(42.2078)).toBe(0.422);
  });
});

describe("monthlyReportExcel workbooks", () => {
  it("builds Resumen with label column and formatted values", () => {
    const wb = buildMonthlyReportWorkbook(sampleReport);
    const resumen = wb.Sheets.Resumen;

    expect(resumen.A1?.v).toBe("Reporte mensual");
    expect(resumen.B1?.v).toBe("2026-05");
    expect(resumen.A5?.v).toBe("Valor portafolio (USD)");
    expect(resumen.B5?.v).toBe(553);
    expect(resumen.B5?.z).toBe(USD_FORMAT);
    expect(resumen.A6?.v).toBe("Rendimiento mensual Winbit (%)");
    expect(resumen.B6?.v).toBe(-0.018);
    expect(resumen.B6?.z).toBe(PCT_FORMAT);
    expect(resumen.A7?.v).toBe("Acumulado desde ingreso (USD)");
    expect(resumen.B7?.v).toBe("");
  });

  it("builds Anexo with headers and formatted rows", () => {
    const wb = buildMonthlyReportWorkbook(sampleReport);
    const anexo = wb.Sheets.Anexo;

    expect(anexo.A1?.v).toBe("MARCELA MANAVELLA");
    expect(anexo.G1?.v).toBe("VALOR PORTAFOLIO");
    expect(anexo.A2?.v).toBe("INGRESO");
    expect(anexo.G2?.v).toBe(500);
    expect(anexo.A3?.v).toBeTruthy();
  });

  it("builds all-investors workbook with stacked annex blocks", () => {
    const other: MonthlyReport = {
      ...sampleReport,
      investor: { id: "2", name: "Agostina Carrió", email: "ag@test.com" },
    };
    const wb = buildAllInvestorsWorkbook([sampleReport, other]);
    expect(wb.Sheets.Resumen.A1?.v).toBe("Inversor");

    const totalCount = Object.keys(wb.Sheets.Anexo).filter(
      (key) => !key.startsWith("!") && wb.Sheets.Anexo[key]?.v === "TOTAL",
    ).length;
    expect(totalCount).toBe(2);
  });
});
