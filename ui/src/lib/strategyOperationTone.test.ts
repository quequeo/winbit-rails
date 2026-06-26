import { describe, it, expect } from "vitest";
import {
  strategyOperationTone,
  strategyOperationToneClass,
} from "./strategyOperationTone";

describe("strategyOperationTone", () => {
  it("marks positive and negative rows", () => {
    expect(strategyOperationTone({ resultLabel: "POSITIVO" })).toBe("positive");
    expect(strategyOperationTone({ resultLabel: "NEGATIVO" })).toBe("negative");
    expect(strategyOperationTone({ resultUsd: 850 })).toBe("positive");
    expect(strategyOperationTone({ resultUsd: -712 })).toBe("negative");
  });

  it("maps tone to css classes", () => {
    expect(strategyOperationToneClass("positive")).toBe("text-success");
    expect(strategyOperationToneClass("negative")).toBe("text-error");
  });
});
