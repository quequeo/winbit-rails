import { formatCurrencyAR, formatPercentAR } from "../lib/formatters";
import type { ApiInvestorPortfolio } from "../types";

// Same figures, labels and calculation as page 2 of the monthly PDF report
// and the investor app: every return is net of the service cost.

type Props = {
  portfolio?: ApiInvestorPortfolio | null;
  compact?: boolean;
};

const MONTH_NAMES = [
  "Enero",
  "Febrero",
  "Marzo",
  "Abril",
  "Mayo",
  "Junio",
  "Julio",
  "Agosto",
  "Septiembre",
  "Octubre",
  "Noviembre",
  "Diciembre",
];

const currentMonthName = () => MONTH_NAMES[new Date().getMonth()];
const currentYear = () => new Date().getFullYear();

function MetricCell({
  label,
  usd,
  percent,
  compact,
}: {
  label: string;
  usd?: number | null;
  percent?: number | null;
  compact?: boolean;
}) {
  const valueClass = compact
    ? "mt-0.5 font-mono text-xs font-semibold text-t-primary"
    : "mt-1 font-mono text-sm font-semibold text-t-primary";

  return (
    <div>
      <p className="text-xs text-t-dim">{label}</p>
      <p className={valueClass}>{formatCurrencyAR(usd ?? 0)}</p>
      <p className={`${valueClass} text-t-muted`}>
        {formatPercentAR(percent ?? 0)}
      </p>
    </div>
  );
}

export function InvestorDashboardMetrics({ portfolio, compact = false }: Props) {
  if (!portfolio) {
    return <p className="text-xs text-t-dim">Sin portfolio</p>;
  }

  const valueClass = compact
    ? "mt-0.5 font-mono text-xs font-semibold text-t-primary"
    : "mt-1 font-mono text-sm font-semibold text-t-primary";

  return (
    <div
      className={
        compact
          ? "grid grid-cols-2 gap-x-3 gap-y-2 sm:grid-cols-3"
          : "grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5"
      }
    >
      <div>
        <p className="text-xs text-t-dim">Valor del portafolio</p>
        <p className={valueClass}>
          {formatCurrencyAR(portfolio.currentBalance ?? 0)}
        </p>
      </div>
      <div>
        <p className="text-xs text-t-dim">Capital aportado neto</p>
        <p className={valueClass}>
          {formatCurrencyAR(portfolio.netContributedUSD ?? 0)}
        </p>
      </div>
      <MetricCell
        label={`Rendimiento mensual · ${currentMonthName()} ${currentYear()}`}
        usd={portfolio.monthReturnNetUSD}
        percent={portfolio.monthReturnNetPercent}
        compact={compact}
      />
      <MetricCell
        label={`Rendimiento acumulado ${currentYear()}`}
        usd={portfolio.strategyReturnYtdNetUSD}
        percent={portfolio.strategyReturnYtdNetPercent}
        compact={compact}
      />
      <MetricCell
        label="Rendimiento acumulado desde el ingreso"
        usd={portfolio.strategyReturnAllNetUSD}
        percent={portfolio.strategyReturnAllNetPercent}
        compact={compact}
      />
    </div>
  );
}

const INVESTOR_DASHBOARD_TABLE_COLUMNS = 7;

export function InvestorDashboardTableCells({
  portfolio,
}: {
  portfolio?: ApiInvestorPortfolio | null;
}) {
  if (!portfolio) {
    return (
      <>
        {Array.from({ length: INVESTOR_DASHBOARD_TABLE_COLUMNS }).map((_, index) => (
          <td
            key={index}
            className="py-3 pr-4 text-right font-mono text-xs text-t-dim"
          >
            —
          </td>
        ))}
      </>
    );
  }

  const rows: Array<{ value: number | null | undefined; kind: "usd" | "pct" }> = [
    { value: portfolio.netContributedUSD, kind: "usd" },
    { value: portfolio.monthReturnNetUSD, kind: "usd" },
    { value: portfolio.monthReturnNetPercent, kind: "pct" },
    { value: portfolio.strategyReturnYtdNetUSD, kind: "usd" },
    { value: portfolio.strategyReturnYtdNetPercent, kind: "pct" },
    { value: portfolio.strategyReturnAllNetUSD, kind: "usd" },
    { value: portfolio.strategyReturnAllNetPercent, kind: "pct" },
  ];

  return (
    <>
      {rows.map(({ value, kind }, index) => (
        <td
          key={index}
          className="py-3 pr-4 text-right font-mono text-xs text-t-primary whitespace-nowrap"
        >
          {kind === "usd"
            ? formatCurrencyAR(value ?? 0)
            : formatPercentAR(value ?? 0)}
        </td>
      ))}
    </>
  );
}
