import type { StrategyOperationFormValues } from "../components/StrategyOperationFields";
import {
  emptyStrategyOperationForm,
  mapApiRowToStrategyForm,
  STRATEGY_ASSETS,
  STRATEGY_RESULT_LABELS,
} from "../components/StrategyOperationFields";

const TIME_FORMAT = /^([01]\d|2[0-3]):[0-5]\d$/;

const parseOptionalNumber = (raw: string) => {
  const cleaned = raw.trim();
  if (!cleaned) return undefined;
  const normalized = cleaned.replace(/\./g, "").replace(/,/g, ".");
  const n = Number(normalized);
  return Number.isFinite(n) ? n : undefined;
};

export const mapStrategyOperationToForm = mapApiRowToStrategyForm;

export const validateStrategyOperationForm = (
  values: StrategyOperationFormValues,
): string | null => {
  if (!values.asset.trim()) return null;

  if (!STRATEGY_ASSETS.includes(values.asset as (typeof STRATEGY_ASSETS)[number])) {
    return "Seleccioná un activo válido (MNQ, MBT, MYM, MES).";
  }

  if (
    !values.result_label ||
    !STRATEGY_RESULT_LABELS.includes(
      values.result_label as (typeof STRATEGY_RESULT_LABELS)[number],
    )
  ) {
    return "Seleccioná un resultado válido (POSITIVO, NEGATIVO, BE+, BE-).";
  }

  if (!TIME_FORMAT.test(values.opened_at.trim())) {
    return "Apertura inválida. Usá formato hora HH:MM (ej: 12:08).";
  }

  if (!TIME_FORMAT.test(values.closed_at.trim())) {
    return "Cierre inválido. Usá formato hora HH:MM (ej: 12:10).";
  }

  return null;
};

export const buildStrategyOperationPayload = (
  values: StrategyOperationFormValues,
) => {
  if (!values.asset.trim()) return undefined;

  return {
    asset: values.asset.trim(),
    timeframe: values.timeframe.trim() || undefined,
    direction: values.direction || undefined,
    result_label: values.result_label || undefined,
    ratio: parseOptionalNumber(values.ratio),
    opened_at: values.opened_at.trim(),
    closed_at: values.closed_at.trim(),
    notes: values.notes.trim() || undefined,
  };
};

export { emptyStrategyOperationForm };
