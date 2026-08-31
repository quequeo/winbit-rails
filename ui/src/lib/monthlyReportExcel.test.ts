import { describe, it, expect } from "vitest";
import * as XLSX from "xlsx-js-style";
import {
  buildMonthlyReportWorkbook,
  buildAllInvestorsWorkbook,
  pctToDecimalOneDec,
  pctToDecimalTwoDec,
  roundUsd,
  roundUsdTwoDec,
  PCT_FORMAT,
  PCT_FORMAT_RESUMEN,
  USD_FORMAT,
  USD_FORMAT_CENTS,
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
  it("rounds USD to two decimals for Resumen", () => {
    expect(roundUsdTwoDec(6750.04)).toBe(6750.04);
    expect(roundUsdTwoDec(-116.25)).toBe(-116.25);
    expect(roundUsd(6750.04)).toBe(6750);
  });

  it("converts percent points to two-decimal Excel decimal for Resumen", () => {
    expect(pctToDecimalTwoDec(6.8321)).toBe(0.0683);
    expect(pctToDecimalTwoDec(42.2078)).toBe(0.4221);
  });

  it("converts percent points to one-decimal Excel decimal", () => {
    expect(pctToDecimalOneDec(-1.78)).toBe(-0.018);
    expect(pctToDecimalOneDec(42.2078)).toBe(0.422);
  });
});

const sampleOperations = {
  trades: [
    {
      date: "02/07",
      asset: "MNQ",
      direction: "LONG",
      openedAt: "10:22",
      closedAt: "10:41",
      resultUsd: 44,
      resultPercent: 0.5,
      ratio: 0.9,
    },
    {
      date: "03/07",
      asset: "MES",
      direction: "SHORT",
      openedAt: "11:08",
      closedAt: "11:24",
      resultUsd: -45,
      resultPercent: 0.5,
      ratio: -1,
    },
  ],
  assets: [
    { code: "MNQ", name: "Micro E-mini Nasdaq-100" },
    { code: "MES", name: "Micro E-mini S&P 500" },
  ],
  count: 2,
  positive: 1,
  negative: 1,
  breakEven: 0,
  netResultUsd: -1,
};

describe("monthlyReportExcel workbooks", () => {
  it("includes net contributed, monthly USD return and year-opening in Resumen", () => {
    const report: MonthlyReport = {
      ...sampleReport,
      summary: {
        ...sampleReport.summary,
        netContributedUsd: 5050,
        yearOpeningDate: "2026-01-01",
        yearOpeningBalanceUsd: 7736,
      },
    };
    const wb = buildMonthlyReportWorkbook(report);
    const resumen = wb.Sheets.Resumen;

    expect(resumen.A6?.v).toBe("Capital aportado neto (USD)");
    expect(resumen.B6?.v).toBe(5050);
    expect(resumen.A7?.v).toBe("Rendimiento mensual (USD)");
    expect(resumen.B7?.v).toBe(0);
    expect(resumen.A13?.v).toBe("Saldo inicial 2026");
    expect(resumen.B13?.v).toBe("2026-01-01");
    expect(resumen.A14?.v).toBe("Saldo inicial 2026 (USD)");
    expect(resumen.B14?.v).toBe(7736);
  });

  it("adds an Operaciones sheet with the trade table and summary stats", () => {
    const report: MonthlyReport = { ...sampleReport, operations: sampleOperations };
    const wb = buildMonthlyReportWorkbook(report);
    const ops = wb.Sheets.Operaciones;

    expect(ops).toBeDefined();
    expect(ops.A1?.v).toBe("Activos operados");
    expect(ops.B1?.v).toBe("MNQ (Micro E-mini Nasdaq-100), MES (Micro E-mini S&P 500)");
    expect(ops.A3?.v).toBe("Fecha");
    expect(ops.B4?.v).toBe("MNQ");
    expect(ops.F4?.v).toBe(44);
    expect(ops.B5?.v).toBe("MES");
    expect(ops.F5?.v).toBe(-45);
    expect(ops.A11?.v).toBe("Resultado neto (USD)");
    expect(ops.B11?.v).toBe(-1);
  });

  it("omits the Operaciones sheet when there is no operations data", () => {
    const wb = buildMonthlyReportWorkbook(sampleReport);
    expect(wb.Sheets.Operaciones).toBeUndefined();
  });

  it("builds Resumen with label column and formatted values", () => {
    const wb = buildMonthlyReportWorkbook(sampleReport);
    const resumen = wb.Sheets.Resumen;

    expect(resumen.A1?.v).toBe("Reporte mensual");
    expect(resumen.B1?.v).toBe("2026-05");
    expect(resumen.A5?.v).toBe("Valor portafolio (USD)");
    expect(resumen.B5?.v).toBe(553.2);
    expect(resumen.B5?.z).toBe(USD_FORMAT_CENTS);
    expect(resumen.A8?.v).toBe("Rendimiento mensual Winbit (%)");
    expect(resumen.B8?.v).toBe(-0.018);
    expect(resumen.B8?.z).toBe(PCT_FORMAT);
    expect(resumen.A9?.v).toBe("Acumulado desde ingreso (USD)");
    expect(resumen.B9?.v).toBe("");
    expect(resumen.A12?.v).toBe("Acumulado 2026 (%)");
    expect(resumen.B12?.z).toBe(PCT_FORMAT_RESUMEN);
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

  it("TOTAL RDO is net of CST and matches Resumen acumulado 2026", () => {
    const report: MonthlyReport = {
      ...sampleReport,
      summary: {
        ...sampleReport.summary,
        portfolioValueUsd: 7293,
        accumulated2026Usd: 68,
        accumulated2026Percent: 0.98,
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
          portfolioValue: 6951,
          openingSnapshot: true,
          entryRow: false,
          source: "spreadsheet",
        },
        {
          month: "2026-06",
          label: "Jun-26",
          returnPercent: 1.6,
          returnUsd: 117,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 49,
          portfolioValue: 7293,
          openingSnapshot: false,
          entryRow: false,
          source: "platform",
        },
      ],
    };

    const wb = buildMonthlyReportWorkbook(report);
    const resumen = wb.Sheets.Resumen;
    const anexo = wb.Sheets.Anexo;

    expect(anexo.C3?.v).toBe(117);
    expect(anexo.A4?.v).toBe("TOTAL");
    expect(anexo.B4?.v).toBe(0.0098);
    expect(anexo.B4?.z).toBe(PCT_FORMAT_RESUMEN);
    expect(anexo.C4?.v).toBe(68);
    expect(anexo.F4?.v).toBe(49);
    expect(anexo.G4?.v).toBe(342);
    expect(resumen.B11?.v).toBe(68);
    expect(anexo.C4?.v).toBe(resumen.B11?.v);
    expect(resumen.B12?.v).toBe(0.0098);
    expect(anexo.B4?.v).toBe(resumen.B12?.v);
  });

  it("Fabrizio Bruno: Resumen acumulado 2026 matches Anexo TOTAL (neto), not gross RDO sum", () => {
    const report: MonthlyReport = {
      investor: { id: "fb", name: "Fabrizio Bruno", email: "fabrabr190987@gmail.com" },
      reportMonth: "2026-06",
      summary: {
        portfolioValueUsd: 7293,
        winbitMonthlyReturnPercent: 1.6,
        accumulatedSinceEntryUsd: 5430,
        accumulatedSinceEntryPercent: 73.8,
        accumulated2026Usd: 343,
        accumulated2026Percent: 4.93,
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
          portfolioValue: 6951,
          openingSnapshot: true,
          entryRow: false,
          source: "spreadsheet",
        },
        {
          month: "2026-01",
          label: "Jan-26",
          returnPercent: 0,
          returnUsd: -1,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 0,
          portfolioValue: 6950,
          openingSnapshot: false,
          entryRow: false,
          source: "spreadsheet",
        },
        {
          month: "2026-02",
          label: "Feb-26",
          returnPercent: 2,
          returnUsd: 161,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 0,
          portfolioValue: 7111,
          openingSnapshot: false,
          entryRow: false,
          source: "spreadsheet",
        },
        {
          month: "2026-03",
          label: "Mar-26",
          returnPercent: 2.3,
          returnUsd: 164,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 97,
          portfolioValue: 7178,
          openingSnapshot: false,
          entryRow: false,
          source: "spreadsheet",
        },
        {
          month: "2026-04",
          label: "Apr-26",
          returnPercent: 2.5,
          returnUsd: 179,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 0,
          portfolioValue: 7357,
          openingSnapshot: false,
          entryRow: false,
          source: "spreadsheet",
        },
        {
          month: "2026-05",
          label: "May-26",
          returnPercent: -1.8,
          returnUsd: -131,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 0,
          portfolioValue: 7226,
          openingSnapshot: false,
          entryRow: false,
          source: "platform",
        },
        {
          month: "2026-06",
          label: "Jun-26",
          returnPercent: 1.6,
          returnUsd: 117,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 49,
          portfolioValue: 7293,
          openingSnapshot: false,
          entryRow: false,
          source: "platform",
        },
      ],
    };

    const wb = buildMonthlyReportWorkbook(report);
    const resumen = wb.Sheets.Resumen;
    const anexo = wb.Sheets.Anexo;

    expect(anexo.A9?.v).toBe("TOTAL");
    expect(anexo.B9?.v).toBe(0.0493);
    expect(anexo.B9?.z).toBe(PCT_FORMAT_RESUMEN);
    expect(anexo.C9?.v).toBe(343);
    expect(anexo.C9?.v).not.toBe(489);
    expect(anexo.F9?.v).toBe(146);
    expect(anexo.G9?.v).toBe(342);
    expect(resumen.B11?.v).toBe(343);
    expect(anexo.C9?.v).toBe(resumen.B11?.v);
    expect(resumen.B12?.v).toBe(0.0493);
    expect(anexo.B9?.v).toBe(resumen.B12?.v);
  });

  it("Agostina Carrió: TOTAL RDO M % is Acumulado 2026 (%), not blank or sum of monthly %", () => {
    const report: MonthlyReport = {
      investor: {
        id: "ag",
        name: "Agostina Carrió",
        email: "agostina@test.com",
      },
      reportMonth: "2026-07",
      summary: {
        portfolioValueUsd: 5500,
        winbitMonthlyReturnPercent: 1.2,
        accumulatedSinceEntryUsd: 500,
        accumulatedSinceEntryPercent: 10,
        accumulated2026Usd: 516,
        accumulated2026Percent: 10.32,
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
          portfolioValue: 5000,
          openingSnapshot: true,
          entryRow: false,
          source: "spreadsheet",
        },
        {
          month: "2026-05",
          label: "May-26",
          returnPercent: 3.5,
          returnUsd: 175,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 0,
          portfolioValue: 5175,
          openingSnapshot: false,
          entryRow: false,
          source: "platform",
        },
        {
          month: "2026-06",
          label: "Jun-26",
          returnPercent: 4.2,
          returnUsd: 217,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 0,
          portfolioValue: 5392,
          openingSnapshot: false,
          entryRow: false,
          source: "platform",
        },
        {
          month: "2026-07",
          label: "Jul-26",
          returnPercent: 2.0,
          returnUsd: 124,
          deposits: 0,
          withdrawals: 0,
          serviceCost: 0,
          portfolioValue: 5500,
          openingSnapshot: false,
          entryRow: false,
          source: "platform",
        },
      ],
    };

    const wb = buildMonthlyReportWorkbook(report);
    const resumen = wb.Sheets.Resumen;
    const anexo = wb.Sheets.Anexo;

    expect(anexo.A6?.v).toBe("TOTAL");
    // 10.32% as Excel decimal; must match Resumen, not sum of monthly % (9.7).
    expect(anexo.B6?.v).toBe(0.1032);
    expect(anexo.B6?.z).toBe(PCT_FORMAT_RESUMEN);
    expect(anexo.B6?.v).not.toBe(0.097);
    expect(resumen.B12?.v).toBe(0.1032);
    expect(anexo.B6?.v).toBe(resumen.B12?.v);
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
