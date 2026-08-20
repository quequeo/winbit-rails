import { lastClosedMonth } from "./lastClosedMonth";

describe("lastClosedMonth", () => {
  it("returns the previous calendar month as YYYY-MM", () => {
    expect(lastClosedMonth(new Date(2026, 7, 20))).toBe("2026-07");
    expect(lastClosedMonth(new Date(2026, 0, 3))).toBe("2025-12");
  });
});
