import { formatStrategyOperationTime } from "./formatStrategyOperationTime";
import { formatCurrencyAR, formatDateAR, formatNumberAR } from "./formatters";
import type { StrategyOperationExportRow } from "./exportStrategyOperationsToExcel";

const MONTH_NAMES: Record<string, string> = {
  "01": "Enero",
  "02": "Febrero",
  "03": "Marzo",
  "04": "Abril",
  "05": "Mayo",
  "06": "Junio",
  "07": "Julio",
  "08": "Agosto",
  "09": "Septiembre",
  "10": "Octubre",
  "11": "Noviembre",
  "12": "Diciembre",
};

export const periodLabelForGpt = (year: string, month: string): string => {
  if (!year) return "Todos los períodos";
  if (!month) return year;
  return `${MONTH_NAMES[month] ?? month} ${year}`;
};

const cell = (value: string): string => value.replace(/\|/g, "\\|").trim() || "—";

const formatUsdPlain = (value: number | null | undefined): string => {
  if (value == null) return "—";
  return formatNumberAR(value);
};

export const buildStrategyOperationsGptText = (
  rows: StrategyOperationExportRow[],
  periodLabel: string,
): string => {
  const totalUsd = rows.reduce((sum, row) => sum + (row.resultUsd ?? 0), 0);
  const withUsd = rows.filter((row) => row.resultUsd != null);
  const positives = withUsd.filter((row) => (row.resultUsd ?? 0) > 0).length;
  const negatives = withUsd.filter((row) => (row.resultUsd ?? 0) < 0).length;
  const neutrals = withUsd.filter((row) => (row.resultUsd ?? 0) === 0).length;

  const lines = [
    `# Operaciones de estrategia — ${periodLabel}`,
    "",
    `- Cantidad: ${rows.length}`,
    `- Resultado USD total: ${formatCurrencyAR(totalUsd)}`,
    `- Positivas: ${positives} | Negativas: ${negatives} | Neutras: ${neutrals}`,
    "",
    "| Fecha | Activo | TF | Apertura | Cierre | Resultado | USD |",
    "| --- | --- | --- | --- | --- | --- | ---: |",
  ];

  for (const row of rows) {
    lines.push(
      [
        "",
        cell(formatDateAR(row.operationDate, { time: false })),
        cell(row.asset || ""),
        cell(row.timeframe || ""),
        cell(formatStrategyOperationTime(row.openedAt, "")),
        cell(formatStrategyOperationTime(row.closedAt, "")),
        cell(row.resultLabel || ""),
        cell(formatUsdPlain(row.resultUsd)),
        "",
      ].join(" | ").trim(),
    );
  }

  if (rows.length === 0) {
    lines.push("| — | — | — | — | — | — | — |");
  }

  lines.push("");
  lines.push(
    "Analizá estas operaciones de trading: patrones por activo/TF, racha, calidad de resultados y observaciones accionables.",
  );

  return lines.join("\n");
};

export const copyTextToClipboard = async (text: string): Promise<void> => {
  if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }

  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.left = "-9999px";
  document.body.appendChild(textarea);
  textarea.select();
  const ok = document.execCommand("copy");
  document.body.removeChild(textarea);
  if (!ok) {
    throw new Error("No se pudo copiar al portapapeles");
  }
};
