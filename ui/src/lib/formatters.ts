/**
 * Formatea números en formato USD: $XX,XXX.XX
 * - Separador de miles: coma (,)
 * - Separador decimal: punto (.)
 * - Símbolo: $
 */
export const formatCurrencyAR = (value: number): string => {
  const num = typeof value === "string" ? parseFloat(value) : value;
  const abs = Math.abs(num);
  const fixed = abs.toFixed(2);
  const parts = fixed.split(".");
  const integerPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  const result = `$${integerPart}.${parts[1]}`;
  return num < 0 ? `-${result}` : result;
};

/**
 * Formatea números sin símbolo de moneda: XX,XXX.XX
 */
export const formatNumberAR = (value: number): string => {
  const num = typeof value === "string" ? parseFloat(value) : value;
  const fixed = num.toFixed(2);
  const parts = fixed.split(".");
  const integerPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `${integerPart}.${parts[1]}`;
};

/**
 * Formatea porcentajes: XX.XX%
 */
export const formatPercentAR = (value: number): string => {
  const num = typeof value === "string" ? parseFloat(value) : value;
  const fixed = num.toFixed(2);
  const parts = fixed.split(".");
  const integerPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  const sign = num > 0 ? "+" : "";
  return `${sign}${integerPart}.${parts[1]}%`;
};

const MONTHS_SHORT = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

const AR_TZ = "America/Argentina/Buenos_Aires";

/**
 * Formatea fecha en timezone de Argentina.
 * Acepta ISO string, Date o null/undefined.
 * Ejemplo: "13 Mar 2026 - 19:00"
 */
export const formatDateAR = (
  value: string | Date | null | undefined,
  opts: { time?: boolean } = { time: true },
): string => {
  if (!value) return "-";
  const d = typeof value === "string" ? new Date(value) : value;
  if (isNaN(d.getTime())) return "-";

  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: AR_TZ,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });

  const parts: Record<string, string> = {};
  for (const { type, value: v } of formatter.formatToParts(d)) {
    parts[type] = v;
  }

  const day = parts.day;
  const month = MONTHS_SHORT[parseInt(parts.month, 10) - 1];
  const year = parts.year;

  if (opts.time === false) {
    return `${day} ${month} ${year}`;
  }

  const hour = parts.hour;
  const minute = parts.minute;

  return `${day} ${month} ${year} - ${hour}:${minute}`;
};
