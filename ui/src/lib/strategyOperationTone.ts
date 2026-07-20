export type StrategyOperationTone =
  | "positive"
  | "negative"
  | "breakeven"
  | "neutral";

const normalizeLabel = (label?: string | null) =>
  (label || "").trim().toUpperCase();

export const isBreakevenLabel = (label?: string | null): boolean => {
  const normalized = normalizeLabel(label);
  return (
    normalized === "BE+" ||
    normalized === "BE-" ||
    normalized.includes("BE+") ||
    normalized.includes("BE-") ||
    normalized.includes("BREAKEVEN")
  );
};

export const strategyOperationTone = (row: {
  resultLabel?: string | null;
  resultUsd?: number | null;
}): StrategyOperationTone => {
  // Breakeven labels always stay gray, even if USD is non-zero.
  if (isBreakevenLabel(row.resultLabel)) return "breakeven";

  if (row.resultUsd != null) {
    if (row.resultUsd > 0) return "positive";
    if (row.resultUsd < 0) return "negative";
  }

  const label = normalizeLabel(row.resultLabel);
  if (!label) return "neutral";

  if (label.includes("NEGATIVO")) return "negative";
  if (label.includes("POSITIVO")) return "positive";

  return "neutral";
};

export const strategyOperationToneClass = (
  tone: StrategyOperationTone,
): string => {
  if (tone === "positive") return "text-success";
  if (tone === "negative") return "text-error";
  if (tone === "breakeven") return "text-t-dim";
  return "text-t-muted";
};

export type StrategyResultCounts = {
  positive: number;
  negative: number;
  bePlus: number;
  beMinus: number;
};

export const countStrategyResults = (
  rows: Array<{ resultLabel?: string | null }>,
): StrategyResultCounts => {
  const counts: StrategyResultCounts = {
    positive: 0,
    negative: 0,
    bePlus: 0,
    beMinus: 0,
  };

  rows.forEach((row) => {
    const label = normalizeLabel(row.resultLabel);
    if (label === "BE+" || label.includes("BE+")) {
      counts.bePlus += 1;
      return;
    }
    if (label === "BE-" || label.includes("BE-")) {
      counts.beMinus += 1;
      return;
    }
    if (label.includes("POSITIVO")) {
      counts.positive += 1;
      return;
    }
    if (label.includes("NEGATIVO")) {
      counts.negative += 1;
    }
  });

  return counts;
};
