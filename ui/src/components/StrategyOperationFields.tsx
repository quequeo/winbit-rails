import { Input } from "../components/ui/Input";
import { Select } from "../components/ui/Select";

export type StrategyOperationFormValues = {
  asset: string;
  timeframe: string;
  direction: string;
  result_label: string;
  result_usd: string;
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
  result_usd: "",
  ratio: "",
  opened_at: "",
  closed_at: "",
  notes: "",
});

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
          Se guarda en Operaciones (detalle). La rentabilidad que ven los
          inversores sigue siendo la de arriba.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-asset`}>
            Activo
          </label>
          <Input
            id={`${idPrefix}-asset`}
            value={values.asset}
            onChange={(e) => set("asset", e.target.value)}
            placeholder="NQ, MES, BTC..."
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-timeframe`}>
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
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-opened`}>
            Apertura
          </label>
          <Input
            id={`${idPrefix}-opened`}
            value={values.opened_at}
            onChange={(e) => set("opened_at", e.target.value)}
            placeholder="12:08"
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-closed`}>
            Cierre
          </label>
          <Input
            id={`${idPrefix}-closed`}
            value={values.closed_at}
            onChange={(e) => set("closed_at", e.target.value)}
            placeholder="12:10"
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-result`}>
            Resultado
          </label>
          <Input
            id={`${idPrefix}-result`}
            value={values.result_label}
            onChange={(e) => set("result_label", e.target.value)}
            placeholder="POSITIVO, NEGATIVO, BE+..."
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-usd`}>
            USD (trade)
          </label>
          <Input
            id={`${idPrefix}-usd`}
            type="text"
            value={values.result_usd}
            onChange={(e) => set("result_usd", e.target.value)}
            placeholder="850 o -712"
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-ratio`}>
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
          <label className="text-sm font-medium text-t-muted" htmlFor={`${idPrefix}-notes`}>
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
