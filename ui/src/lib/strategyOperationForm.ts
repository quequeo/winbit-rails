import type { StrategyOperationFormValues } from "../components/StrategyOperationFields";
import { emptyStrategyOperationForm } from "../components/StrategyOperationFields";

const parseOptionalNumber = (raw: string) => {
  const cleaned = raw.trim();
  if (!cleaned) return undefined;
  const normalized = cleaned.replace(/\./g, "").replace(/,/g, ".");
  const n = Number(normalized);
  return Number.isFinite(n) ? n : undefined;
};

export const mapStrategyOperationToForm = (
  row?: {
    asset?: string;
    timeframe?: string | null;
    direction?: string | null;
    resultLabel?: string | null;
    resultUsd?: number | null;
    ratio?: number | null;
    openedAt?: string | null;
    closedAt?: string | null;
    notes?: string | null;
  } | null,
): StrategyOperationFormValues => {
  if (!row) return emptyStrategyOperationForm();

  return {
    asset: row.asset || "",
    timeframe: row.timeframe || "",
    direction: row.direction || "",
    result_label: row.resultLabel || "",
    result_usd:
      row.resultUsd != null ? String(row.resultUsd).replace(".", ",") : "",
    ratio: row.ratio != null ? String(row.ratio).replace(".", ",") : "",
    opened_at: row.openedAt || "",
    closed_at: row.closedAt || "",
    notes: row.notes || "",
  };
};

export const buildStrategyOperationPayload = (
  values: StrategyOperationFormValues,
) => {
  if (!values.asset.trim()) return undefined;

  return {
    asset: values.asset.trim(),
    timeframe: values.timeframe.trim() || undefined,
    direction: values.direction || undefined,
    result_label: values.result_label.trim() || undefined,
    result_usd: parseOptionalNumber(values.result_usd),
    ratio: parseOptionalNumber(values.ratio),
    opened_at: values.opened_at.trim() || undefined,
    closed_at: values.closed_at.trim() || undefined,
    notes: values.notes.trim() || undefined,
  };
};
