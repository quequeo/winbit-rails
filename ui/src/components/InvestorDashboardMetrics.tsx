import { formatCurrencyAR, formatPercentAR } from "../lib/formatters";
import type { ApiInvestorPortfolio } from "../types";

type Props = {
  portfolio?: ApiInvestorPortfolio | null;
  compact?: boolean;
};

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

  const year = currentYear();
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
        <p className="text-xs text-t-dim">Capital actual</p>
        <p className={valueClass}>
          {formatCurrencyAR(portfolio.currentBalance ?? 0)}
        </p>
      </div>
      <div>
        <p className="text-xs text-t-dim">Total invertido</p>
        <p className={valueClass}>
          {formatCurrencyAR(portfolio.totalInvested ?? 0)}
        </p>
      </div>
      <MetricCell
        label={`Resultado estrategia ${year} (USD / %)`}
        usd={portfolio.strategyReturnYtdUSD}
        percent={portfolio.strategyReturnYtdPercent}
        compact={compact}
      />
      <MetricCell
        label="Resultado estrategia histórico (USD / %)"
        usd={portfolio.strategyReturnAllUSD}
        percent={portfolio.strategyReturnAllPercent}
        compact={compact}
      />
      <MetricCell
        label="Rentabilidad acumulada (USD / %)"
        usd={portfolio.accumulatedReturnUSD}
        percent={portfolio.accumulatedReturnPercent}
        compact={compact}
      />
      <MetricCell
        label="Rentabilidad anual (USD / %)"
        usd={portfolio.annualReturnUSD}
        percent={portfolio.annualReturnPercent}
        compact={compact}
      />
    </div>
  );
}

export function InvestorDashboardTableCells({
  portfolio,
}: {
  portfolio?: ApiInvestorPortfolio | null;
}) {
  if (!portfolio) {
    return (
      <>
        {Array.from({ length: 9 }).map((_, index) => (
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
    { value: portfolio.totalInvested, kind: "usd" },
    { value: portfolio.strategyReturnYtdUSD, kind: "usd" },
    { value: portfolio.strategyReturnYtdPercent, kind: "pct" },
    { value: portfolio.strategyReturnAllUSD, kind: "usd" },
    { value: portfolio.strategyReturnAllPercent, kind: "pct" },
    { value: portfolio.accumulatedReturnUSD, kind: "usd" },
    { value: portfolio.accumulatedReturnPercent, kind: "pct" },
    { value: portfolio.annualReturnUSD, kind: "usd" },
    { value: portfolio.annualReturnPercent, kind: "pct" },
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
