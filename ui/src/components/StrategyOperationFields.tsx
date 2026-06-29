import { Input } from "../components/ui/Input";
import { Select } from "../components/ui/Select";

export const STRATEGY_ASSETS = ["MNQ", "MBT", "MYM", "MES"] as const;
export const STRATEGY_RESULT_LABELS = ["POSITIVO", "NEGATIVO", "BE+", "BE-"] as const;

const TIME_FORMAT = /^([01]\d|2[0-3]):[0-5]\d$/;

export type StrategyOperationFormValues = {
  asset: string;
  timeframe: string;
  direction: string;
  result_label: string;
  ratio: string;
  opened_at: string;
  closed_at: string;
  notes: string;
};

export const emptyStrategyOperationForm = (): StrategyOperationFormValues => ({
  asset: "",
  timeframe: "",
  direction: "",
  result_label: "",
  ratio: "",
  opened_at: "",
  closed_at: "",
  notes: "",
});

const toTimeInputValue = (value?: string | null) => {
  const text = (value || "").trim();
  return TIME_FORMAT.test(text) ? text : "";
};

type Props = {
  values: StrategyOperationFormValues;
  onChange: (next: StrategyOperationFormValues) => void;
  idPrefix?: string;
};

export const StrategyOperationFields = ({
  values,
  onChange,
  idPrefix = "strategy-op",
}: Props) => {
  const set = (key: keyof StrategyOperationFormValues, value: string) => {
    onChange({ ...values, [key]: value });
  };

  return (
    <div className="space-y-4 rounded-lg border border-b-default bg-dark-section/40 p-4">
      <div>
        <h3 className="text-sm font-semibold text-t-primary">
          Detalle de la operación
        </h3>
        <p className="mt-1 text-xs text-t-dim">
          Se guarda en Operaciones (detalle). El USD del trade coincide con el
          monto USD del día cargado arriba.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted">Activo</label>
          <Select
            value={values.asset}
            onChange={(value) => set("asset", value)}
            options={[
              { value: "", label: "Seleccionar..." },
              ...STRATEGY_ASSETS.map((asset) => ({ value: asset, label: asset })),
            ]}
          />
        </div>
        <div className="space-y-2">
          <label
            className="text-sm font-medium text-t-muted"
            htmlFor={`${idPrefix}-timeframe`}
          >
            Temporalidad
          </label>
          <Input
            id={`${idPrefix}-timeframe`}
            value={values.timeframe}
            onChange={(e) => set("timeframe", e.target.value)}
            placeholder="1m, 2m..."
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted">Dirección</label>
          <Select
            value={values.direction}
            onChange={(value) => set("direction", value)}
            options={[
              { value: "", label: "—" },
              { value: "LONG", label: "LONG" },
              { value: "SHORT", label: "SHORT" },
            ]}
          />
        </div>
        <div className="space-y-2">
          <label
            className="text-sm font-medium text-t-muted"
            htmlFor={`${idPrefix}-opened`}
          >
            Apertura
          </label>
          <Input
            id={`${idPrefix}-opened`}
            type="time"
            value={values.opened_at}
            onChange={(e) => set("opened_at", e.target.value)}
            required={Boolean(values.asset)}
          />
        </div>
        <div className="space-y-2">
          <label
            className="text-sm font-medium text-t-muted"
            htmlFor={`${idPrefix}-closed`}
          >
            Cierre
          </label>
          <Input
            id={`${idPrefix}-closed`}
            type="time"
            value={values.closed_at}
            onChange={(e) => set("closed_at", e.target.value)}
            required={Boolean(values.asset)}
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted">Resultado</label>
          <Select
            value={values.result_label}
            onChange={(value) => set("result_label", value)}
            options={[
              { value: "", label: "Seleccionar..." },
              ...STRATEGY_RESULT_LABELS.map((label) => ({
                value: label,
                label,
              })),
            ]}
          />
        </div>
        <div className="space-y-2">
          <label
            className="text-sm font-medium text-t-muted"
            htmlFor={`${idPrefix}-ratio`}
          >
            Ratio
          </label>
          <Input
            id={`${idPrefix}-ratio`}
            type="text"
            value={values.ratio}
            onChange={(e) => set("ratio", e.target.value)}
            placeholder="1,1"
          />
        </div>
        <div className="space-y-2 md:col-span-3">
          <label
            className="text-sm font-medium text-t-muted"
            htmlFor={`${idPrefix}-notes`}
          >
            Observaciones
          </label>
          <textarea
            id={`${idPrefix}-notes`}
            value={values.notes}
            onChange={(e) => set("notes", e.target.value)}
            rows={2}
            className="w-full rounded-md border border-[rgba(101,167,165,0.25)] bg-[#121716] px-3 py-2 text-sm text-white focus:border-primary focus:outline-none"
            placeholder="Setup, contexto, etc."
          />
        </div>
      </div>
    </div>
  );
};

export const mapApiRowToStrategyForm = (
  row?: {
    asset?: string;
    timeframe?: string | null;
    direction?: string | null;
    resultLabel?: string | null;
    ratio?: number | null;
    openedAt?: string | null;
    closedAt?: string | null;
    notes?: string | null;
  } | null,
): StrategyOperationFormValues => {
  if (!row) return emptyStrategyOperationForm();

  const asset = STRATEGY_ASSETS.includes(row.asset as (typeof STRATEGY_ASSETS)[number])
    ? row.asset!
    : "";

  const resultLabel = STRATEGY_RESULT_LABELS.includes(
    row.resultLabel as (typeof STRATEGY_RESULT_LABELS)[number],
  )
    ? row.resultLabel!
    : "";

  return {
    asset,
    timeframe: row.timeframe || "",
    direction: row.direction || "",
    result_label: resultLabel,
    ratio: row.ratio != null ? String(row.ratio).replace(".", ",") : "",
    opened_at: toTimeInputValue(row.openedAt),
    closed_at: toTimeInputValue(row.closedAt),
    notes: row.notes || "",
  };
};
