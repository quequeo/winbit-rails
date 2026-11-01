import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { formatCurrencyAR } from "../lib/formatters";
import { Button } from "./ui/Button";
import { Input } from "./ui/Input";
import { ConfirmDialog } from "./ui/ConfirmDialog";

const DEFAULT_SUBJECT = "Winbit | Reporte mensual | {mes_titulo}";

const DEFAULT_BODY = `Hola, {primer_nombre}, ¿cómo estás?

Adjuntamos el **reporte mensual de {mes_nombre}**. En el mes, tu capital tuvo un resultado de **{rentabilidad_mes}%**, y en lo que va del año, de **{acumulado_anual}%**. Al cierre del mes, tu capital administrado es de **USD {capital}**.

En el reporte está el detalle de cada operación del mes, para que puedas ver qué hay detrás del resultado y no solo el número final.

Si querés sumar capital, podés hacerlo en cualquier momento desde la app, sin monto mínimo.

[Botón: Ver mi cuenta en la app →]

Ante cualquier consulta, escribinos por [WhatsApp](https://wa.me/5491141783126) o respondé este correo.

**El equipo de Winbit**`;

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

type Schedule = {
  id: string;
  month: string;
  subject: string;
  scheduledFor: string;
  status: "SCHEDULED" | "SENDING" | "SENT" | "CANCELED" | "FAILED";
  sentAt?: string | null;
  queuedCount?: number | null;
  skippedCount?: number | null;
  failureCount?: number | null;
  scheduledBy?: string | null;
};

const WEEKDAYS = [
  "domingo",
  "lunes",
  "martes",
  "miércoles",
  "jueves",
  "viernes",
  "sábado",
];

const pad2 = (n: number) => String(n).padStart(2, "0");

// Próximo día hábil a las 8:00 (hora local del navegador).
const nextBusinessMorning = (now = new Date()) => {
  const d = new Date(now);
  d.setDate(d.getDate() + 1);
  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T08:00`;
};

const formatScheduleDate = (iso: string) => {
  const d = new Date(iso);
  return `${WEEKDAYS[d.getDay()]} ${pad2(d.getDate())}/${pad2(d.getMonth() + 1)} a las ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
};

export const MonthlyReportEmailPanel = ({ month }: Props) => {
  const [subject, setSubject] = useState(DEFAULT_SUBJECT);
  const [body, setBody] = useState(DEFAULT_BODY);
  const [investorId, setInvestorId] = useState("");
  const [testEmail, setTestEmail] = useState("");
  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [showMassDialog, setShowMassDialog] = useState(false);
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [scheduleAt, setScheduleAt] = useState(() => nextBusinessMorning());
  const [showScheduleDialog, setShowScheduleDialog] = useState(false);

  const loadSchedules = useCallback(async () => {
    try {
      const res = (await api.getMonthlyReportEmailSchedules(month)) as {
        data?: Schedule[];
      };
      setSchedules(res?.data ?? []);
    } catch {
      setSchedules([]);
    }
  }, [month]);

  useEffect(() => {
    void loadSchedules();
  }, [loadSchedules]);

  const pendingSchedule = schedules.find(
    (s) => s.status === "SCHEDULED" || s.status === "SENDING",
  );
  const lastSent = schedules.find((s) => s.status === "SENT");

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
  // A test uses the selected investor, or the preview's sample one if none
  // was picked, so it can be sent without choosing anybody first.
  const testInvestorId = investorId || preview?.sampleInvestor?.id || "";
  const testInvestorName =
    recipients.find((row) => row.id === testInvestorId)?.name ||
    preview?.sampleInvestor?.name ||
    "—";

  const handleSendOne = async (toTestEmail?: string) => {
    const targetId = toTestEmail ? testInvestorId : investorId;
    if (!targetId) {
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
        investor_id: targetId,
        ...(toTestEmail ? { test_email: toTestEmail } : {}),
      })) as { data?: { queuedCount?: number; failureCount?: number } };
      const queued = res?.data?.queuedCount ?? 0;
      const failures = res?.data?.failureCount ?? 0;
      setSuccess(
        toTestEmail
          ? `Prueba enviada a ${toTestEmail} con el mail y el PDF de este inversor (queued=${queued}, fallos=${failures}).`
          : `Email enviado a 1 inversor con el PDF del mes (queued=${queued}, fallos=${failures}).`,
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

  const handleSchedule = async () => {
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      const scheduledFor = new Date(scheduleAt);
      if (Number.isNaN(scheduledFor.getTime())) {
        throw new Error("Elegí una fecha y hora válidas.");
      }
      await api.scheduleMonthlyReportEmailMass({
        month,
        subject,
        body,
        scheduled_for: scheduledFor.toISOString(),
      });
      setSuccess(
        `Envío programado para el ${formatScheduleDate(scheduledFor.toISOString())}.`,
      );
      await loadSchedules();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al programar el envío");
    } finally {
      setSending(false);
      setShowScheduleDialog(false);
    }
  };

  const handleCancelSchedule = async (id: string) => {
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      await api.cancelMonthlyReportEmailSchedule(id);
      setSuccess("Envío programado cancelado.");
      await loadSchedules();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cancelar");
    } finally {
      setSending(false);
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
            className="w-full rounded-md border border-[rgba(71,151,133,0.25)] bg-[#111513] px-3 py-2 text-sm text-t-primary focus:border-primary focus:outline-none focus:ring-1 focus:ring-[rgba(71,151,133,0.3)]"
          />
          <p className="mt-2 text-xs text-t-dim">
            Variables (con una o dos llaves):{" "}
            {[
              "primer_nombre",
              "nombre",
              "rentabilidad_mes",
              "acumulado_anual",
              "capital",
              "mes_nombre",
              "mes_titulo",
              "ganancia_usd",
              "ganancia_pct",
            ].map((name, index) => (
              <span key={name}>
                {index > 0 && ", "}
                <code className="text-primary">{`{${name}}`}</code>
              </span>
            ))}
            . Los valores son los mismos del reporte PDF de cada inversor,
            netos del costo del servicio. Formato:{" "}
            <code className="text-primary">**negrita**</code>,{" "}
            <code className="text-primary">*cursiva*</code> y{" "}
            <code className="text-primary">[Botón: texto]</code> para el botón
            a la app,{" "}
            <code className="text-primary">[texto](https://...)</code> para un
            enlace (el número de WhatsApp de Winbit se enlaza solo). La firma de Winbit se agrega sola al final.
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
            disabled={
              sending ||
              audienceCount === 0 ||
              Boolean(investorId) ||
              Boolean(pendingSchedule)
            }
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

      <div className="admin-card p-6 space-y-3">
        <h3 className="text-sm font-semibold text-t-primary">
          Enviar una prueba
        </h3>
        <p className="text-xs text-t-dim">
          {`Te llega el mail con el PDF de ${testInvestorName} a la dirección que pongas, tal como lo recibiría el inversor. No se le manda nada al inversor. Para probar con otro, tocalo en la lista de destinatarios.`}
        </p>
        <div className="flex flex-wrap items-center gap-3">
          <div className="w-72">
            <Input
              type="email"
              value={testEmail}
              onChange={(e) => setTestEmail(e.target.value)}
              placeholder="tu correo, ej. contacto@winbit.com.ar"
              aria-label="Correo de prueba"
            />
          </div>
          <Button
            type="button"
            variant="outline"
            onClick={() => void handleSendOne(testEmail.trim())}
            disabled={sending || !testInvestorId || !testEmail.trim()}
          >
            Enviar prueba
          </Button>
        </div>
      </div>

      <div className="admin-card p-6 space-y-3">
        <h3 className="text-sm font-semibold text-t-primary">
          Programar envío a todos los elegibles
        </h3>
        {pendingSchedule ? (
          <div className="flex flex-wrap items-center gap-3">
            <p className="text-sm text-success">
              {pendingSchedule.status === "SENDING"
                ? "Enviando ahora…"
                : `Programado para el ${formatScheduleDate(pendingSchedule.scheduledFor)}`}
              {pendingSchedule.scheduledBy
                ? ` (por ${pendingSchedule.scheduledBy})`
                : ""}
              . Asunto: “{pendingSchedule.subject}”.
            </p>
            {pendingSchedule.status === "SCHEDULED" ? (
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={sending}
                onClick={() => void handleCancelSchedule(pendingSchedule.id)}
              >
                Cancelar programación
              </Button>
            ) : null}
          </div>
        ) : (
          <div className="flex flex-wrap items-center gap-3">
            <input
              type="datetime-local"
              value={scheduleAt}
              onChange={(e) => setScheduleAt(e.target.value)}
              aria-label="Fecha y hora de envío"
              className="rounded-md border border-[rgba(71,151,133,0.25)] bg-[#111513] px-3 py-2 text-sm text-t-primary focus:border-primary focus:outline-none"
            />
            <Button
              type="button"
              variant="outline"
              disabled={
                sending ||
                audienceCount === 0 ||
                Boolean(investorId) ||
                !scheduleAt
              }
              onClick={() => setShowScheduleDialog(true)}
            >
              Programar envío
            </Button>
          </div>
        )}
        <p className="text-xs text-t-dim">
          Sale solo a la hora elegida, con el asunto y el cuerpo que están
          escritos al programar. Los destinatarios y los PDFs se toman al
          momento del envío: si regenerás un PDF antes, sale el último.
        </p>
        {lastSent ? (
          <p className="text-xs text-t-muted">
            Último envío programado: {formatScheduleDate(lastSent.sentAt || lastSent.scheduledFor)} ·{" "}
            {lastSent.queuedCount ?? 0} enviados, {lastSent.failureCount ?? 0} fallos.
          </p>
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

      <ConfirmDialog
        isOpen={showScheduleDialog}
        onClose={() => setShowScheduleDialog(false)}
        onConfirm={() => {
          void handleSchedule();
        }}
        title="Confirmar envío programado"
        message={`El reporte de ${month} se va a enviar el ${
          scheduleAt ? formatScheduleDate(new Date(scheduleAt).toISOString()) : "—"
        } a los inversores elegibles en ese momento (hoy: ${audienceCount}), con el PDF adjunto. ¿Programar?`}
        confirmText="Programar"
        confirmVariant="primary"
      />
    </div>
  );
};
