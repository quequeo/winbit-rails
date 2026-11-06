import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api } from "../lib/api";
import { downloadMonthlyReportExcel } from "../lib/monthlyReportExcel";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { formatDateAR } from "../lib/formatters";
import type { MonthlyReport } from "../types";

const DEFAULT_SUBJECT = "Winbit | ";

const DEFAULT_BODY = `Hola, {primer_nombre}, ¿cómo estás?



**El equipo de Winbit**`;

// Argentina no tiene horario de verano: siempre UTC-3.
const AR_OFFSET = "-03:00";

const SCHEDULE_STATUS_LABELS: Record<string, string> = {
  SCHEDULED: "Programado",
  SENDING: "Enviando",
  SENT: "Enviado",
  CANCELED: "Cancelado",
  FAILED: "Falló",
};

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

type Schedule = {
  id: string;
  subject: string;
  scheduledFor: string;
  status: string;
  audienceCount?: number | null;
  queuedCount?: number | null;
  failureCount?: number | null;
};

type Audience = "all" | "selected";

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
  const [audience, setAudience] = useState<Audience>(
    investorIdParam ? "selected" : "all",
  );
  const [selectedIds, setSelectedIds] = useState<string[]>(
    investorIdParam ? [investorIdParam] : [],
  );
  const [sampleId, setSampleId] = useState(investorIdParam);
  const [appButton, setAppButton] = useState(false);
  const [testEmail, setTestEmail] = useState("");
  const [scheduleAt, setScheduleAt] = useState("");
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [showScheduleDialog, setShowScheduleDialog] = useState(false);
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [confirmMass, setConfirmMass] = useState(false);
  const [showMassDialog, setShowMassDialog] = useState(false);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);
  const [attachmentsById, setAttachmentsById] = useState<Record<string, File>>(
    {},
  );
  const fileInputRefs = useRef<Record<string, HTMLInputElement | null>>({});

  useEffect(() => {
    if (!investorIdParam) return;
    setAudience("selected");
    setSelectedIds([investorIdParam]);
    setSampleId(investorIdParam);
  }, [investorIdParam]);

  const loadSchedules = useCallback(async () => {
    try {
      const res = (await api.getEmailCampaignSchedules()) as {
        data?: Schedule[];
      };
      setSchedules(res?.data ?? []);
    } catch (e) {
      setError(
        e instanceof Error ? e.message : "Error al cargar los programados",
      );
    }
  }, []);

  useEffect(() => {
    void loadSchedules();
  }, [loadSchedules]);

  const loadPreview = useCallback(async () => {
    setLoadingPreview(true);
    setError(null);
    try {
      const res = (await api.previewEmailCampaign({
        month,
        subject,
        body,
        sample_investor_id: sampleId || undefined,
      })) as { data?: PreviewData };
      setPreview(res?.data ?? null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al previsualizar");
      setPreview(null);
    } finally {
      setLoadingPreview(false);
    }
  }, [month, subject, body, sampleId]);

  useEffect(() => {
    void loadPreview();
  }, [month, sampleId]); // eslint-disable-line react-hooks/exhaustive-deps -- preview on month/sample; subject/body via button

  const activeCount = preview?.audienceCount ?? 0;
  const audienceCount =
    audience === "selected" ? selectedIds.length : activeCount;
  const investorIdsToSend = audience === "selected" ? selectedIds : undefined;
  const sendDisabled = sending || audienceCount === 0;
  const modeLabel =
    audience === "selected" ? "Inversores elegidos" : "Todos los activos";

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

  const toggleSelected = (id: string, checked: boolean) => {
    setSelectedIds((prev) =>
      checked ? [...new Set([...prev, id])] : prev.filter((x) => x !== id),
    );
  };

  const handleSendTest = async () => {
    const sample = preview?.sampleInvestor;
    if (!sample) {
      setError("No hay un inversor de ejemplo para armar la prueba.");
      return;
    }
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      const id = String(sample.id);
      const res = (await api.sendEmailCampaignOne({
        month,
        subject,
        body,
        investor_id: id,
        attachment: attachmentsById[id] || null,
        test_email: testEmail.trim(),
        app_button: appButton,
      })) as { data?: { failureCount?: number } };
      if ((res?.data?.failureCount ?? 0) > 0) {
        setError("No se pudo enviar la prueba.");
      } else {
        setSuccess(
          `Prueba enviada a ${testEmail.trim()}, con los datos de ${sample.name}.`,
        );
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al enviar la prueba");
    } finally {
      setSending(false);
    }
  };

  const handleSchedule = async () => {
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      await api.scheduleEmailCampaign({
        month,
        subject,
        body,
        scheduled_for: `${scheduleAt}:00${AR_OFFSET}`,
        investor_ids: investorIdsToSend,
        app_button: appButton,
      });
      setSuccess(
        `Listo: el correo quedó programado para ${audienceCount} inversores.`,
      );
      setScheduleAt("");
      await loadSchedules();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al programar");
    } finally {
      setSending(false);
      setShowScheduleDialog(false);
    }
  };

  const handleCancelSchedule = async (id: string) => {
    setError(null);
    setSuccess(null);
    try {
      await api.cancelEmailCampaignSchedule(id);
      setSuccess("Envío programado cancelado.");
      await loadSchedules();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cancelar");
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
        investor_ids: investorIdsToSend,
        app_button: appButton,
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
        attachmentCount > 0 ? ` (${attachmentCount} con adjunto)` : "";
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

  const recipientsPreview = useMemo(() => preview?.recipients || [], [preview]);

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
            Correos personalizados a inversores, para enviar en el momento o
            programar. Se envían aunque las notificaciones globales estén
            desactivadas, y quedan en el Historial de Correos.
          </p>
        </div>
        <Link to="/investors" className="text-sm text-primary hover:underline">
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
              Mes de referencia
            </label>
            <Input
              type="month"
              value={month}
              onChange={(e) => setMonth(e.target.value)}
            />
            <p className="mt-1 text-xs text-t-dim">
              Define los datos de las variables de rendimiento.
            </p>
          </div>
          <fieldset>
            <legend className="mb-1 block text-sm font-medium text-t-muted">
              Destinatarios
            </legend>
            <label className="flex items-center gap-2 text-sm text-t-primary">
              <input
                type="radio"
                name="audience"
                checked={audience === "all"}
                onChange={() => setAudience("all")}
              />
              Todos los activos
            </label>
            <label className="mt-1 flex items-center gap-2 text-sm text-t-primary">
              <input
                type="radio"
                name="audience"
                checked={audience === "selected"}
                onChange={() => setAudience("selected")}
              />
              Elegir inversores
            </label>
          </fieldset>
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
            className="w-full rounded-md border border-[rgba(71,151,133,0.25)] bg-[#111513] px-3 py-2 text-sm text-t-primary focus:border-primary focus:outline-none focus:ring-1 focus:ring-[rgba(71,151,133,0.3)]"
          />
          <p className="mt-2 text-xs text-t-dim">
            Variables:{" "}
            <code className="text-primary">{"{{primer_nombre}}"}</code>,{" "}
            <code className="text-primary">{"{{nombre}}"}</code>,{" "}
            <code className="text-primary">{"{{ganancia_usd}}"}</code>,{" "}
            <code className="text-primary">{"{{ganancia_pct}}"}</code>,{" "}
            <code className="text-primary">{"{{email}}"}</code>,{" "}
            <code className="text-primary">{"{{mes}}"}</code>. Los saltos de
            línea se convierten en &lt;br&gt;.
          </p>
        </div>

        <label className="flex items-center gap-2 text-sm text-t-muted">
          <input
            type="checkbox"
            checked={appButton}
            onChange={(e) => setAppButton(e.target.checked)}
          />
          Agregar el botón "Ver mi cuenta en la app" al final
        </label>

        <div>
          <Button
            type="button"
            variant="outline"
            onClick={() => void loadPreview()}
            disabled={loadingPreview}
          >
            {loadingPreview ? "Actualizando…" : "Actualizar preview"}
          </Button>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <div>
            <label
              htmlFor="campaignTestEmail"
              className="mb-1 block text-sm font-medium text-t-muted"
            >
              1. Enviar una prueba a
            </label>
            <div className="flex gap-2">
              <Input
                id="campaignTestEmail"
                type="email"
                value={testEmail}
                onChange={(e) => setTestEmail(e.target.value)}
                placeholder="tu@correo.com"
              />
              <Button
                type="button"
                variant="outline"
                disabled={
                  sending || !testEmail.trim() || !preview?.sampleInvestor
                }
                onClick={() => void handleSendTest()}
              >
                Enviar prueba
              </Button>
            </div>
            <p className="mt-1 text-xs text-t-dim">
              Solo llega a ese correo, con los datos de {sampleName}. No queda
              en el Historial.
            </p>
          </div>
          <div>
            <label
              htmlFor="campaignScheduleAt"
              className="mb-1 block text-sm font-medium text-t-muted"
            >
              2. Programar para (hora de Argentina)
            </label>
            <div className="flex gap-2">
              <Input
                id="campaignScheduleAt"
                type="datetime-local"
                value={scheduleAt}
                onChange={(e) => setScheduleAt(e.target.value)}
              />
              <Button
                type="button"
                disabled={sendDisabled || !scheduleAt || attachmentCount > 0}
                onClick={() => setShowScheduleDialog(true)}
              >
                Programar
              </Button>
            </div>
            <p className="mt-1 text-xs text-t-dim">
              {attachmentCount > 0
                ? "Los correos con adjunto no se pueden programar: enviá ahora o quitá los adjuntos."
                : `Sale solo a ${audienceCount} inversores.`}
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3 border-t border-b-default pt-4">
          <Button
            type="button"
            variant="outline"
            disabled={sendDisabled}
            onClick={() => setShowMassDialog(true)}
          >
            Enviar ahora
          </Button>
          <label className="flex items-start gap-2 text-sm text-t-muted">
            <input
              type="checkbox"
              checked={confirmMass}
              onChange={(e) => setConfirmMass(e.target.checked)}
              className="mt-1"
            />
            <span>Confirmo envío a {audienceCount} inversores</span>
          </label>
        </div>
      </div>

      {schedules.length > 0 ? (
        <div className="admin-card p-6">
          <h3 className="mb-3 text-sm font-semibold text-t-primary">
            Envíos programados
          </h3>
          <ul className="space-y-2 text-sm">
            {schedules.map((s) => (
              <li
                key={s.id}
                className="flex flex-wrap items-center justify-between gap-2 border-t border-b-default pt-2"
              >
                <div className="min-w-0">
                  <p className="truncate text-t-primary">{s.subject}</p>
                  <p className="text-xs text-t-muted">
                    {SCHEDULE_STATUS_LABELS[s.status] ?? s.status} ·{" "}
                    {formatDateAR(s.scheduledFor)} ·{" "}
                    {s.audienceCount
                      ? `${s.audienceCount} inversores`
                      : "Todos los activos"}
                    {s.status === "SENT"
                      ? ` · ${s.queuedCount ?? 0} enviados, ${s.failureCount ?? 0} fallos`
                      : ""}
                  </p>
                </div>
                {s.status === "SCHEDULED" ? (
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => void handleCancelSchedule(s.id)}
                  >
                    Cancelar
                  </Button>
                ) : null}
              </li>
            ))}
          </ul>
        </div>
      ) : null}

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
            Inversores activos ({activeCount})
          </h3>
          <p className="mb-2 text-xs text-t-dim">
            Tocá un nombre para verlo en el preview. ↓ descarga el Excel del
            mes. Podés subir un adjunto PDF/XLSX (máx. 10MB) por inversor.
          </p>
          <div className="max-h-96 overflow-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-t-dim">
                  {audience === "selected" ? (
                    <th className="pb-2 pr-2">
                      <span className="sr-only">Elegir</span>
                    </th>
                  ) : null}
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
                      {audience === "selected" ? (
                        <td className="py-2 pr-2">
                          <input
                            type="checkbox"
                            aria-label={`Elegir a ${r.name}`}
                            checked={selectedIds.includes(id)}
                            onChange={(e) =>
                              toggleSelected(id, e.target.checked)
                            }
                          />
                        </td>
                      ) : null}
                      <td className="py-2 pr-2">
                        <div className="flex items-center gap-1.5 min-w-0">
                          <button
                            type="button"
                            className="min-w-0 truncate text-left text-primary hover:underline"
                            onClick={() => setSampleId(id)}
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
        title="Confirmar envío"
        message={`Se enviará ahora mismo a ${audienceCount} inversores${
          attachmentCount > 0
            ? ` (${attachmentCount} con adjunto PDF/XLSX)`
            : ""
        }. ¿Continuar?`}
        confirmText="Enviar ahora"
        confirmVariant="primary"
      />

      <ConfirmDialog
        isOpen={showScheduleDialog}
        onClose={() => setShowScheduleDialog(false)}
        onConfirm={() => void handleSchedule()}
        title="Programar envío"
        message={`Saldrá automáticamente a ${audienceCount} inversores el ${
          scheduleAt ? formatDateAR(`${scheduleAt}:00${AR_OFFSET}`) : ""
        }. ¿Confirmás?`}
        confirmText="Programar"
        confirmVariant="primary"
      />
    </div>
  );
};
