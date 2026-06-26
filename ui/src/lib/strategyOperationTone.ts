export type StrategyOperationTone = "positive" | "negative" | "neutral";

export const strategyOperationTone = (row: {
  resultLabel?: string | null;
  resultUsd?: number | null;
}): StrategyOperationTone => {
  if (row.resultUsd != null) {
    if (row.resultUsd > 0) return "positive";
    if (row.resultUsd < 0) return "negative";
  }

  const label = (row.resultLabel || "").trim().toUpperCase();
  if (!label) return "neutral";

  if (label.includes("NEGATIVO") || label.includes("BE-")) return "negative";
  if (label.includes("POSITIVO") || label.includes("BE+")) return "positive";

  return "neutral";
};

export const strategyOperationToneClass = (tone: StrategyOperationTone): string => {
  if (tone === "positive") return "text-success";
  if (tone === "negative") return "text-error";
  return "text-t-muted";
};
