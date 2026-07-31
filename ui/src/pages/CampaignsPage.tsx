import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api } from "../lib/api";
import { downloadMonthlyReportExcel } from "../lib/monthlyReportExcel";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import type { MonthlyReport } from "../types";

const DEFAULT_SUBJECT =
  "Winbit | Informe de rendimiento {{mes}}";

const DEFAULT_BODY = `Hola {{nombre}},

Te compartimos el resumen de rendimiento de {{mes}}.

Ganancia del mes: {{ganancia_pct}} ({{ganancia_usd}}).

Podés ver el detalle en tu panel de inversión.

Saludos,
Equipo Winbit`;

const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
const ALLOWED_ATTACHMENT_EXT = /\.(pdf|xlsx)$/i;

const defaultCampaignMonth = () => {
  const d = new Date();
  d.setDate(1);
  d.setMonth(d.getMonth() - 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
};

type Recipient = {
  id: number | string;
  name: string;
  email: string;
  gananciaUsd?: string;
  gananciaPct?: string;
  error?: string;
};

type PreviewData = {
  month: string;
  audienceCount: number;
  variables: string[];
  recipients: Recipient[];
  sampleSubject?: string | null;
  sampleBodyHtml?: string | null;
  sampleInvestor?: { id: number | string; name: string; email: string } | null;
};

function validateAttachmentFile(file: File): string | null {
  if (!ALLOWED_ATTACHMENT_EXT.test(file.name)) {
    return "Solo se permiten PDF o XLSX";
  }
  if (file.size > MAX_ATTACHMENT_BYTES) {
    return "El adjunto supera 10MB";
  }
  if (file.size === 0) {
    return "El adjunto está vacío";
  }
  return null;
}

export const CampaignsPage = () => {
  const [searchParams] = useSearchParams();
  const investorIdParam = searchParams.get("investorId") || "";

  const [month, setMonth] = useState(defaultCampaignMonth);
  const [subject, setSubject] = useState(DEFAULT_SUBJECT);
  const [body, setBody] = useState(DEFAULT_BODY);
  const [investorId, setInvestorId] = useState(investorIdParam);
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [confirmMass, setConfirmMass] = useState(false);
  const [showMassDialog, setShowMassDialog] = useState(false);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);
  const [attachmentsById, setAttachmentsById] = useState<
    Record<string, File>
  >({});
  const fileInputRefs = useRef<Record<string, HTMLInputElement | null>>({});

  useEffect(() => {
    if (investorIdParam) setInvestorId(investorIdParam);
  }, [investorIdParam]);

  const loadPreview = useCallback(async () => {
    setLoadingPreview(true);
    setError(null);
    try {
      const res = (await api.previewEmailCampaign({
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
  }, [month, investorId]); // eslint-disable-line react-hooks/exhaustive-deps -- preview on month/investor; subject/body via button

  const audienceCount = preview?.audienceCount ?? 0;
  const modeLabel = investorId
    ? "Envío a un inversor"
    : "Campaña masiva (activos)";

  const sampleName = preview?.sampleInvestor?.name || "—";
  const attachmentCount = Object.keys(attachmentsById).length;

  const handleAttachmentChange = (recipientId: string, file: File | null) => {
    if (!file) {
      setAttachmentsById((prev) => {
        const next = { ...prev };
        delete next[recipientId];
        return next;
      });
      return;
    }
    const validationError = validateAttachmentFile(file);
    if (validationError) {
      setError(`${file.name}: ${validationError}`);
      const input = fileInputRefs.current[recipientId];
      if (input) input.value = "";
      return;
    }
    setError(null);
    setAttachmentsById((prev) => ({ ...prev, [recipientId]: file }));
  };

  const clearAttachment = (recipientId: string) => {
    setAttachmentsById((prev) => {
      const next = { ...prev };
      delete next[recipientId];
      return next;
    });
    const input = fileInputRefs.current[recipientId];
    if (input) input.value = "";
  };

  const handleSendOne = async () => {
    if (!investorId) {
      setError("Seleccioná un inversor (o usá el link desde Inversores).");
      return;
    }
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      const attachment = attachmentsById[investorId] || null;
      const res = (await api.sendEmailCampaignOne({
        month,
        subject,
        body,
        investor_id: investorId,
        attachment,
      })) as {
        data?: { queuedCount?: number; failureCount?: number };
      };
      const queued = res?.data?.queuedCount ?? 0;
      const failures = res?.data?.failureCount ?? 0;
      const attachedNote = attachment ? ` (con adjunto ${attachment.name})` : "";
      setSuccess(
        `Email encolado para 1 inversor${attachedNote} (queued=${queued}, fallos=${failures}).`,
      );
      await loadPreview();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al enviar");
    } finally {
      setSending(false);
    }
  };

  const handleSendMass = async () => {
    if (!confirmMass) {
      setError('Marcá "Confirmo envío a N inversores" antes de enviar.');
      return;
    }
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      const res = (await api.sendEmailCampaignMass({
        month,
        subject,
        body,
        confirm: true,
        attachmentsByInvestorId: attachmentsById,
      })) as {
        data?: {
          queuedCount?: number;
          skippedCount?: number;
          failureCount?: number;
          totalAudience?: number;
        };
      };
      const d = res?.data;
      const attachedNote =
        attachmentCount > 0
          ? ` (${attachmentCount} con adjunto)`
          : "";
      setSuccess(
        `Campaña encolada: ${d?.queuedCount ?? 0} enviados${attachedNote}, ${d?.skippedCount ?? 0} omitidos, ${d?.failureCount ?? 0} fallos (audiencia ${d?.totalAudience ?? 0}).`,
      );
      setConfirmMass(false);
      await loadPreview();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al enviar masivo");
    } finally {
      setSending(false);
      setShowMassDialog(false);
    }
  };

  const recipientsPreview = useMemo(
    () => preview?.recipients || [],
    [preview],
  );

  const handleDownloadReport = async (recipient: Recipient) => {
    const id = String(recipient.id);
    setDownloadingId(id);
    setError(null);
    try {
      const res = await api.getInvestorMonthlyReport(id, month);
      downloadMonthlyReportExcel((res as { data: MonthlyReport }).data);
    } catch (e) {
      setError(
        e instanceof Error ? e.message : "Error al descargar reporte Excel",
      );
    } finally {
      setDownloadingId(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
        <div>
          <h2 className="text-xl font-semibold text-t-primary">
            Campañas / Emails
          </h2>
          <p className="mt-1 text-sm text-t-muted">
            Informe mensual personalizado. Las campañas admin se envían aunque
            las notificaciones globales estén desactivadas. From:{" "}
            <code className="text-t-dim">noreply@winbit.com.ar</code> · Reply-To:{" "}
            <code className="text-t-dim">winbit.cfds@gmail.com</code>.
          </p>
        </div>
        <Link
          to="/investors"
          className="text-sm text-primary hover:underline"
        >
          Volver a inversores
        </Link>
      </div>

      {error ? (
        <div className="admin-card border border-error/40 p-4 text-sm text-error">
          {error}
        </div>
      ) : null}
      {success ? (
        <div className="admin-card border border-success/40 p-4 text-sm text-success">
          {success}
        </div>
      ) : null}

      <div className="admin-card p-6 space-y-4">
        <div className="grid gap-4 md:grid-cols-3">
          <div>
            <label className="mb-1 block text-sm font-medium text-t-muted">
              Mes del informe
            </label>
            <Input
              type="month"
              value={month}
              onChange={(e) => setMonth(e.target.value)}
            />
            <p className="mt-1 text-xs text-t-dim">
              Por defecto: mes calendario anterior (completo).
            </p>
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-t-muted">
              Inversor (opcional, envío individual)
            </label>
            <Input
              type="text"
              value={investorId}
              onChange={(e) => setInvestorId(e.target.value.trim())}
              placeholder="ID del inversor"
            />
            <p className="mt-1 text-xs text-t-dim">
              Vacío = audiencia masiva (ACTIVE con email).
            </p>
          </div>
          <div className="flex items-end">
            <p className="text-sm text-t-muted">
              Modo: <span className="text-t-primary">{modeLabel}</span>
              <br />
              Audiencia:{" "}
              <span className="text-t-primary">
                {loadingPreview ? "…" : audienceCount}
              </span>
              {attachmentCount > 0 ? (
                <>
                  <br />
                  Adjuntos:{" "}
                  <span className="text-t-primary">{attachmentCount}</span>
                </>
              ) : null}
            </p>
          </div>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-t-muted">
            Asunto
          </label>
          <Input
            type="text"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-t-muted">
            Cuerpo (texto plano)
          </label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            rows={12}
            className="w-full rounded-md border border-[rgba(101,167,165,0.25)] bg-[#121716] px-3 py-2 text-sm text-white focus:border-primary focus:outline-none focus:ring-1 focus:ring-[rgba(101,167,165,0.3)]"
          />
          <p className="mt-2 text-xs text-t-dim">
            Variables:{" "}
            <code className="text-primary">{"{{nombre}}"}</code>,{" "}
            <code className="text-primary">{"{{ganancia_usd}}"}</code>,{" "}
            <code className="text-primary">{"{{ganancia_pct}}"}</code>,{" "}
            <code className="text-primary">{"{{email}}"}</code>,{" "}
            <code className="text-primary">{"{{mes}}"}</code>. Los saltos de
            línea se convierten en &lt;br&gt;.
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
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
            Enviar a todos (activos)
          </Button>
        </div>

        {!investorId ? (
          <label className="flex items-start gap-2 text-sm text-t-muted">
            <input
              type="checkbox"
              checked={confirmMass}
              onChange={(e) => setConfirmMass(e.target.checked)}
              className="mt-1"
            />
            <span>
              Confirmo envío a {audienceCount} inversores activos (omite
              NotificationGate; usa Resend).
            </span>
          </label>
        ) : null}
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
          <p className="mb-2 text-xs text-t-dim">Cuerpo HTML</p>
          <div
            className="min-h-40 rounded-md border border-b-default bg-white px-4 py-3 text-sm text-gray-800"
            dangerouslySetInnerHTML={{
              __html: preview?.sampleBodyHtml || "<p>—</p>",
            }}
          />
        </div>

        <div className="admin-card p-6">
          <h3 className="mb-3 text-sm font-semibold text-t-primary">
            Destinatarios ({audienceCount})
          </h3>
          <p className="mb-2 text-xs text-t-dim">
            ↓ descarga el Excel del mes. 📎 sube un adjunto PDF/XLSX (máx.
            10MB) por inversor; solo se envía a quienes tengan archivo.
          </p>
          <div className="max-h-96 overflow-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-t-dim">
                  <th className="pb-2 pr-2">Nombre</th>
                  <th className="pb-2 pr-2">USD</th>
                  <th className="pb-2 pr-2">%</th>
                  <th className="pb-2">Adjunto</th>
                </tr>
              </thead>
              <tbody>
                {recipientsPreview.map((r) => {
                  const id = String(r.id);
                  const file = attachmentsById[id];
                  return (
                    <tr key={id} className="border-t border-b-default">
                      <td className="py-2 pr-2">
                        <div className="flex items-center gap-1.5 min-w-0">
                          <button
                            type="button"
                            className="min-w-0 truncate text-left text-primary hover:underline"
                            onClick={() => setInvestorId(id)}
                          >
                            {r.name}
                          </button>
                          <button
                            type="button"
                            onClick={() => void handleDownloadReport(r)}
                            disabled={downloadingId === id}
                            className="shrink-0 rounded px-1.5 py-0.5 text-sm font-semibold text-primary hover:bg-primary-dim disabled:opacity-50"
                            title="Descargar reporte Excel"
                            aria-label={`Descargar Excel de ${r.name}`}
                          >
                            {downloadingId === id ? "…" : "↓"}
                          </button>
                        </div>
                        <div className="text-xs text-t-dim">{r.email}</div>
                      </td>
                      <td className="py-2 pr-2 text-t-primary">
                        {r.gananciaUsd ?? "—"}
                      </td>
                      <td className="py-2 pr-2 text-t-primary">
                        {r.gananciaPct ?? "—"}
                      </td>
                      <td className="py-2">
                        <div className="flex flex-col gap-1 min-w-[8rem]">
                          <input
                            ref={(el) => {
                              fileInputRefs.current[id] = el;
                            }}
                            type="file"
                            accept=".pdf,.xlsx,application/pdf,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                            className="block w-full max-w-[11rem] text-[11px] text-t-dim file:mr-2 file:rounded file:border-0 file:bg-primary-dim file:px-2 file:py-0.5 file:text-xs file:text-primary"
                            aria-label={`Adjuntar archivo para ${r.name}`}
                            onChange={(e) => {
                              const selected = e.target.files?.[0] ?? null;
                              handleAttachmentChange(id, selected);
                            }}
                          />
                          {file ? (
                            <div className="flex items-center gap-1 text-[11px] text-success">
                              <span className="truncate" title={file.name}>
                                {file.name}
                              </span>
                              <button
                                type="button"
                                className="shrink-0 text-error hover:underline"
                                onClick={() => clearAttachment(id)}
                                aria-label={`Quitar adjunto de ${r.name}`}
                              >
                                ✕
                              </button>
                            </div>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <ConfirmDialog
        isOpen={showMassDialog}
        onClose={() => setShowMassDialog(false)}
        onConfirm={() => {
          if (!confirmMass) {
            setError(
              `Marcá "Confirmo envío a ${audienceCount} inversores" antes de confirmar.`,
            );
            return;
          }
          void handleSendMass();
        }}
        title="Confirmar envío masivo"
        message={`Se encolarán emails personalizados a ${audienceCount} inversores ACTIVE del mes ${month}${
          attachmentCount > 0
            ? ` (${attachmentCount} con adjunto PDF/XLSX)`
            : ""
        }. ¿Continuar?`}
        confirmText="Enviar ahora"
        confirmVariant="primary"
      />
    </div>
  );
};
