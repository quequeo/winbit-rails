import { describe, it, expect } from "vitest";
import {
  buildStrategyOperationsGptText,
  periodLabelForGpt,
} from "./copyStrategyOperationsForGpt";

describe("copyStrategyOperationsForGpt", () => {
  it("builds human period labels", () => {
    expect(periodLabelForGpt("", "")).toBe("Todos los períodos");
    expect(periodLabelForGpt("2026", "")).toBe("2026");
    expect(periodLabelForGpt("2026", "05")).toBe("Mayo 2026");
  });

  it("builds markdown table with context and totals", () => {
    const text = buildStrategyOperationsGptText(
      [
        {
          operationDate: "2026-05-04",
          asset: "NQ",
          timeframe: "M5",
          openedAt: "09:30",
          closedAt: "10:15",
          resultLabel: "POSITIVO",
          resultUsd: 850,
        },
        {
          operationDate: "2026-05-05",
          asset: "ES",
          timeframe: "M15",
          openedAt: "11:00",
          closedAt: "11:40",
          resultLabel: "NEGATIVO",
          resultUsd: -200,
        },
      ],
      "Mayo 2026",
    );

    expect(text).toContain("# Operaciones de estrategia — Mayo 2026");
    expect(text).toContain("- Cantidad: 2");
    expect(text).toContain("- Resultado USD total: $650.00");
    expect(text).toContain("- Positivas: 1 | Negativas: 1 | Neutras: 0");
    expect(text).toContain(
      "| Fecha | Activo | TF | Apertura | Cierre | Resultado | USD |",
    );
    expect(text).toContain("| 4 May 2026 | NQ | M5 | 09:30 | 10:15 | POSITIVO | 850.00 |");
    expect(text).toContain("| 5 May 2026 | ES | M15 | 11:00 | 11:40 | NEGATIVO | -200.00 |");
    expect(text).toContain("Analizá estas operaciones");
  });

  it("handles empty rows", () => {
    const text = buildStrategyOperationsGptText([], "2026");
    expect(text).toContain("- Cantidad: 0");
    expect(text).toContain("- Resultado USD total: $0.00");
    expect(text).toContain("| — | — | — | — | — | — | — |");
  });
});
