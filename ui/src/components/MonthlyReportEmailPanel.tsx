import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { formatCurrencyAR } from "../lib/formatters";
import { Button } from "./ui/Button";
import { Input } from "./ui/Input";
import { ConfirmDialog } from "./ui/ConfirmDialog";

const DEFAULT_SUBJECT = "Winbit | Reporte {{mes}}";

const DEFAULT_BODY = `Hola {{nombre}},

Adjuntamos tu reporte de rendimiento de {{mes}}.

Ganancia del mes: {{ganancia_pct}} ({{ganancia_usd}}).

Saludos,
Equipo Winbit`;

type Recipient = {
  id: string;
  name: string;
  email: string;
  hasPdf: boolean;
  balance: number;
  pdfFilename?: string | null;
  gananciaUsd?: string;
  gananciaPct?: string;
};

type SkippedRow = {
  id: string;
  name: string;
  email: string;
  hasPdf: boolean;
  balance: number;
  skipReason: string;
  skipMessage: string;
};

type PreviewData = {
  month: string;
  audienceCount: number;
  variables: string[];
  recipients: Recipient[];
  skipped: SkippedRow[];
  sampleSubject?: string | null;
  sampleBodyHtml?: string | null;
  sampleInvestor?: { id: string; name: string; email: string } | null;
};

type Props = {
  month: string;
};

export const MonthlyReportEmailPanel = ({ month }: Props) => {
  const [subject, setSubject] = useState(DEFAULT_SUBJECT);
  const [body, setBody] = useState(DEFAULT_BODY);
  const [investorId, setInvestorId] = useState("");
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [showMassDialog, setShowMassDialog] = useState(false);

  const loadPreview = useCallback(async () => {
    setLoadingPreview(true);
    setError(null);
    try {
      const res = (await api.previewMonthlyReportEmail({
        month,
        subject,
        body,
        investor_id: investorId || undefined,
      })) as { data?: PreviewData };
      setPreview(res?.data ?? null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al previsualizar");
      setPreview(null);
    } finally {
      setLoadingPreview(false);
    }
  }, [month, subject, body, investorId]);

  useEffect(() => {
    void loadPreview();
  }, [month, investorId]); // eslint-disable-line react-hooks/exhaustive-deps -- subject/body via button

  const audienceCount = preview?.audienceCount ?? 0;
  const recipients = preview?.recipients || [];
  const skipped = preview?.skipped || [];
  const skippedActive = useMemo(
    () => skipped.filter((row) => row.skipReason !== "inactive"),
    [skipped],
  );
  const skippedInactiveCount = skipped.length - skippedActive.length;
  const sampleName = preview?.sampleInvestor?.name || "—";

  const handleSendOne = async () => {
    if (!investorId) {
      setError("Seleccioná un inversor de la lista para enviar uno.");
      return;
    }
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      const res = (await api.sendMonthlyReportEmailOne({
        month,
        subject,
        body,
        investor_id: investorId,
      })) as { data?: { queuedCount?: number; failureCount?: number } };
      const queued = res?.data?.queuedCount ?? 0;
      const failures = res?.data?.failureCount ?? 0;
      setSuccess(
        `Email enviado a 1 inversor con el PDF del mes (queued=${queued}, fallos=${failures}).`,
      );
      await loadPreview();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al enviar");
    } finally {
      setSending(false);
    }
  };

  const handleSendMass = async () => {
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      const res = (await api.sendMonthlyReportEmailMass({
        month,
        subject,
        body,
        confirm: true,
      })) as {
        data?: {
          queuedCount?: number;
          skippedCount?: number;
          failureCount?: number;
          totalAudience?: number;
        };
      };
      const d = res?.data;
      setSuccess(
        `Envío listo: ${d?.queuedCount ?? 0} enviados, ${d?.skippedCount ?? 0} omitidos, ${d?.failureCount ?? 0} fallos (audiencia ${d?.totalAudience ?? 0}).`,
      );
      await loadPreview();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al enviar masivo");
    } finally {
      setSending(false);
      setShowMassDialog(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="admin-card p-6 space-y-4">
        <p className="text-sm text-t-muted">
          Escribí el asunto y el cuerpo de este mes. Se adjunta el PDF ya
          cargado. Solo reciben inversores ACTIVE con PDF del mes y balance
          mayor a 0. From:{" "}
          <code className="text-t-dim">noreply@winbit.com.ar</code> · Reply-To:{" "}
          <code className="text-t-dim">winbit.cfds@gmail.com</code>.
        </p>

        {error ? (
          <div className="rounded-md border border-error/40 p-3 text-sm text-error">
            {error}
          </div>
        ) : null}
        {success ? (
          <div className="rounded-md border border-success/40 p-3 text-sm text-success">
            {success}
          </div>
        ) : null}

        <div>
          <label className="mb-1 block text-sm font-medium text-t-muted">
            Asunto
          </label>
          <Input
            type="text"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            aria-label="Asunto del email"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-t-muted">
            Cuerpo (texto plano)
          </label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            rows={10}
            aria-label="Cuerpo del email"
            className="w-full rounded-md border border-[rgba(101,167,165,0.25)] bg-[#121716] px-3 py-2 text-sm text-white focus:border-primary focus:outline-none focus:ring-1 focus:ring-[rgba(101,167,165,0.3)]"
          />
          <p className="mt-2 text-xs text-t-dim">
            Variables:{" "}
            <code className="text-primary">{"{{nombre}}"}</code>,{" "}
            <code className="text-primary">{"{{ganancia_usd}}"}</code>,{" "}
            <code className="text-primary">{"{{ganancia_pct}}"}</code>,{" "}
            <code className="text-primary">{"{{email}}"}</code>,{" "}
            <code className="text-primary">{"{{mes}}"}</code>.{" "}
            <code className="text-primary">{"{{nombre}}"}</code> usa el nombre
            completo, igual que en Campañas.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <Button
            type="button"
            variant="outline"
            onClick={() => void loadPreview()}
            disabled={loadingPreview}
          >
            {loadingPreview ? "Actualizando…" : "Actualizar preview"}
          </Button>
          <Button
            type="button"
            onClick={() => void handleSendOne()}
            disabled={sending || !investorId}
          >
            Enviar a este inversor
          </Button>
          <Button
            type="button"
            disabled={sending || audienceCount === 0 || Boolean(investorId)}
            onClick={() => setShowMassDialog(true)}
          >
            Enviar a todos los elegibles
          </Button>
          {investorId ? (
            <Button
              type="button"
              variant="ghost"
              onClick={() => setInvestorId("")}
            >
              Ver todos
            </Button>
          ) : null}
          <p className="text-sm text-t-muted">
            Elegibles:{" "}
            <span className="text-t-primary">
              {loadingPreview ? "…" : audienceCount}
            </span>
            {investorId ? (
              <>
                {" "}
                · Envío individual
              </>
            ) : null}
          </p>
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="admin-card p-6">
          <h3 className="mb-3 text-sm font-semibold text-t-primary">
            Preview ({sampleName})
          </h3>
          <p className="mb-2 text-xs text-t-dim">Asunto</p>
          <p className="mb-4 rounded-md bg-dark-section px-3 py-2 text-sm text-t-primary">
            {preview?.sampleSubject || "—"}
          </p>
          <p className="mb-2 text-xs text-t-dim">Cuerpo</p>
          <div
            className="min-h-40 rounded-md border border-b-default bg-white px-4 py-3 text-sm text-gray-800"
            dangerouslySetInnerHTML={{
              __html: preview?.sampleBodyHtml || "<p>—</p>",
            }}
          />
        </div>

        <div className="admin-card p-6">
          <h3 className="mb-3 text-sm font-semibold text-t-primary">
            Reciben ({audienceCount})
          </h3>
          <p className="mb-2 text-xs text-t-dim">
            Revisá nombre, email, PDF y balance antes de enviar. Clic en el
            nombre para previsualizar y enviar uno.
          </p>
          {recipients.length === 0 ? (
            <p className="text-sm text-t-muted">
              Nadie es elegible para este mes.
            </p>
          ) : (
            <div className="max-h-96 overflow-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="text-t-dim">
                    <th className="pb-2 font-medium">Inversor</th>
                    <th className="pb-2 font-medium">PDF</th>
                    <th className="pb-2 font-medium">Balance</th>
                    <th className="pb-2 font-medium">USD</th>
                    <th className="pb-2 font-medium">%</th>
                  </tr>
                </thead>
                <tbody>
                  {recipients.map((row) => (
                    <tr key={row.id} className="border-t border-b-default">
                      <td className="py-2 pr-2">
                        <button
                          type="button"
                          className="text-left text-primary hover:underline"
                          onClick={() => setInvestorId(row.id)}
                        >
                          {row.name}
                        </button>
                        <div className="text-xs text-t-dim">{row.email}</div>
                      </td>
                      <td
                        className="py-2 pr-2 text-success"
                        title={row.pdfFilename || undefined}
                      >
                        {row.hasPdf ? "Sí" : "No"}
                      </td>
                      <td className="py-2 pr-2 text-t-primary">
                        {formatCurrencyAR(row.balance)}
                      </td>
                      <td className="py-2 pr-2 text-t-primary">
                        {row.gananciaUsd ?? "—"}
                      </td>
                      <td className="py-2 text-t-primary">
                        {row.gananciaPct ?? "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {skippedActive.length > 0 ? (
        <div className="admin-card overflow-x-auto p-6">
          <h3 className="mb-3 text-sm font-semibold text-t-primary">
            Omitidos ({skippedActive.length})
          </h3>
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="text-t-dim">
                <th className="pb-2 font-medium">Inversor</th>
                <th className="pb-2 font-medium">Email</th>
                <th className="pb-2 font-medium">PDF</th>
                <th className="pb-2 font-medium">Balance</th>
                <th className="pb-2 font-medium">Motivo</th>
              </tr>
            </thead>
            <tbody>
              {skippedActive.map((row) => (
                <tr key={row.id} className="border-t border-b-default">
                  <td className="py-2 text-t-primary">{row.name}</td>
                  <td className="py-2 text-t-muted">{row.email}</td>
                  <td className="py-2 text-t-muted">
                    {row.hasPdf ? "Sí" : "No"}
                  </td>
                  <td className="py-2 text-t-muted">
                    {formatCurrencyAR(row.balance)}
                  </td>
                  <td className="py-2 text-warning">{row.skipMessage}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {skippedInactiveCount > 0 ? (
            <p className="mt-3 text-xs text-t-dim">
              También se omiten {skippedInactiveCount} inversores inactivos.
            </p>
          ) : null}
        </div>
      ) : skippedInactiveCount > 0 ? (
        <p className="text-xs text-t-dim">
          Se omiten {skippedInactiveCount} inversores inactivos.
        </p>
      ) : null}

      <ConfirmDialog
        isOpen={showMassDialog}
        onClose={() => setShowMassDialog(false)}
        onConfirm={() => {
          void handleSendMass();
        }}
        title="Confirmar envío masivo"
        message={`Se enviará el reporte de ${month} a ${audienceCount} ${
          audienceCount === 1 ? "inversor" : "inversores"
        } (ACTIVE, con PDF y balance mayor a 0), con el PDF adjunto. ¿Continuar?`}
        confirmText="Enviar ahora"
        confirmVariant="primary"
      />
    </div>
  );
};
