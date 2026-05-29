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
  investor: { id: "1", name: "Eugenio Carrió", email: "eugenio@test.com" },
  reportMonth: "2026-05",
  summary: {
    portfolioValueUsd: 6750.04,
    winbitMonthlyReturnPercent: -1.78,
    accumulatedSinceEntryUsd: 2322.75,
    accumulatedSinceEntryPercent: 42.2078,
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
  it("builds single-investor workbook with formatted cells", () => {
    const wb = buildMonthlyReportWorkbook(sampleReport);
    expect(wb.SheetNames).toEqual(["Resumen", "Anexo"]);

    const resumen = wb.Sheets.Resumen;
    expect(resumen.B5?.v).toBe(6750);
    expect(resumen.B5?.z).toBe(USD_FORMAT);
    expect(resumen.B6?.v).toBe(-0.018);
    expect(resumen.B6?.z).toBe(PCT_FORMAT);

    const anexo = wb.Sheets.Anexo;
    expect(anexo.C3?.v).toBe(-116);
    expect(anexo.C3?.z).toBe(USD_FORMAT);
    expect(anexo.B3?.v).toBe(-0.018);
    expect(anexo.B3?.z).toBe(PCT_FORMAT);
  });

  it("builds all-investors workbook with stacked annex blocks", () => {
    const other: MonthlyReport = {
      ...sampleReport,
      investor: { id: "2", name: "Agostina Carrió", email: "ag@test.com" },
    };
    const wb = buildAllInvestorsWorkbook([sampleReport, other]);
    expect(wb.SheetNames).toEqual(["Resumen", "Anexo"]);
    expect(wb.Sheets.Resumen.A1?.v).toBe("Inversor");
    expect(wb.Sheets.Resumen.A2?.v).toBe("Agostina Carrió");
    expect(wb.Sheets.Resumen.A3?.v).toBe("Eugenio Carrió");

    const totalCount = Object.keys(wb.Sheets.Anexo).filter(
      (key) => !key.startsWith("!") && wb.Sheets.Anexo[key]?.v === "TOTAL",
    ).length;
    expect(totalCount).toBe(2);
  });
});
