import { describe, it, expect } from "vitest";
import {
  buildMonthOptions,
  buildQuarterOptions,
  buildSemesterOptions,
} from "./tradingFeePeriodOptions";

describe("tradingFeePeriodOptions", () => {
  it("includes Q2 on the last day of June", () => {
    const opts = buildQuarterOptions(new Date(2026, 5, 30));
    expect(opts[0]).toMatchObject({
      label: "Q2 2026",
      start: "2026-04-01",
      end: "2026-06-30",
    });
  });

  it("uses Q1 before the quarter closes", () => {
    const opts = buildQuarterOptions(new Date(2026, 5, 29));
    expect(opts[0]).toMatchObject({
      label: "Q1 2026",
      start: "2026-01-01",
      end: "2026-03-31",
    });
  });

  it("includes June on the last day of the month", () => {
    const opts = buildMonthOptions(new Date(2026, 5, 30));
    expect(opts[0]).toMatchObject({
      label: "Jun 2026",
      start: "2026-06-01",
      end: "2026-06-30",
    });
  });

  it("includes first semester on 30 June", () => {
    const opts = buildSemesterOptions(new Date(2026, 5, 30));
    expect(opts[0]).toMatchObject({
      label: "1er Sem 2026",
      start: "2026-01-01",
      end: "2026-06-30",
    });
  });
});
