import {
  operatingContractInfo,
  operatingDirection,
} from "../lib/operatingAsset";

type Props = {
  asset: string | null | undefined;
  direction?: string | null;
  // compact: solo el código del contrato ("MBT"), para tablas angostas.
  compact?: boolean;
};

// Logo, contrato y LONG/SHORT en una sola fila, como en la app del inversor.
export const OperatingAsset = ({ asset, direction, compact = false }: Props) => {
  const info = operatingContractInfo(asset);
  const side = operatingDirection(direction);

  if (!info && !asset) return <span className="text-sm text-t-dim">—</span>;

  return (
    <div className="flex min-w-0 items-center gap-2">
      {info ? (
        <span
          className="flex h-7 w-7 shrink-0 items-center justify-center overflow-hidden rounded-full border border-b-default bg-dark-section"
          title={info.name}
        >
          <img src={info.logo} alt="" className="h-[78%] w-[78%] object-contain" />
        </span>
      ) : null}
      <span className="truncate whitespace-nowrap text-sm font-semibold text-t-primary">
        {info ? (compact ? info.contract : `${info.contract} — ${info.name}`) : asset}
      </span>
      {side ? (
        <span className="shrink-0 rounded border border-[rgba(236,228,213,0.45)] px-1.5 py-px text-[0.625rem] font-semibold uppercase tracking-wide text-t-primary">
          {side}
        </span>
      ) : null}
    </div>
  );
};
