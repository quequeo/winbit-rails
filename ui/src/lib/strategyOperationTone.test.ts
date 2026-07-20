import { describe, it, expect } from "vitest";
import {
  strategyOperationTone,
  strategyOperationToneClass,
  countStrategyResults,
  isBreakevenLabel,
} from "./strategyOperationTone";

describe("strategyOperationTone", () => {
  it("marks positive and negative rows", () => {
    expect(strategyOperationTone({ resultLabel: "POSITIVO" })).toBe("positive");
    expect(strategyOperationTone({ resultLabel: "NEGATIVO" })).toBe("negative");
    expect(strategyOperationTone({ resultUsd: 850 })).toBe("positive");
    expect(strategyOperationTone({ resultUsd: -712 })).toBe("negative");
  });

  it("keeps breakeven gray even with non-zero USD", () => {
    expect(isBreakevenLabel("BE-")).toBe(true);
    expect(
      strategyOperationTone({ resultLabel: "BE-", resultUsd: -1654.02 }),
    ).toBe("breakeven");
    expect(
      strategyOperationTone({ resultLabel: "BE+", resultUsd: 120 }),
    ).toBe("breakeven");
  });

  it("maps tone to css classes", () => {
    expect(strategyOperationToneClass("positive")).toBe("text-success");
    expect(strategyOperationToneClass("negative")).toBe("text-error");
    expect(strategyOperationToneClass("breakeven")).toBe("text-t-dim");
  });

  it("counts result labels", () => {
    expect(
      countStrategyResults([
        { resultLabel: "POSITIVO" },
        { resultLabel: "NEGATIVO" },
        { resultLabel: "BE+" },
        { resultLabel: "BE-" },
        { resultLabel: "BE-" },
      ]),
    ).toEqual({ positive: 1, negative: 1, bePlus: 1, beMinus: 2 });
  });
});
