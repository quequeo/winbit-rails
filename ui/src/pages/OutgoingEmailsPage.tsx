import { useCallback, useEffect, useState } from "react";
import { api } from "../lib/api";
import type { ApiOutgoingEmail } from "../types";
import { Button } from "../components/ui/Button";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { formatDateAR } from "../lib/formatters";

const KIND_LABELS: Record<string, string> = {
  DEPOSIT_APPROVED: "Ingreso aprobado",
  WITHDRAWAL_APPROVED: "Retiro aprobado",
  DEPOSIT_REJECTED: "Ingreso rechazado",
  WITHDRAWAL_REJECTED: "Retiro rechazado",
  INVESTOR_WELCOME: "Alta de inversor",
  INVESTOR_DEACTIVATED: "Baja de inversor",
};

const STATUS_LABELS: Record<string, string> = {
  DRAFT: "Para revisar",
  SCHEDULED: "Programado",
  FAILED: "Falló el envío",
  SENT: "Enviado",
  DISCARDED: "Descartado",
};

// Argentina no tiene horario de verano: siempre UTC-3.
const AR_OFFSET = "-03:00";

const toArInput = (iso: string | null | undefined): string => {
  const base = iso ? new Date(iso) : new Date(Date.now() + 60 * 60 * 1000);
  return new Date(base.getTime() - 3 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 16);
};

export const OutgoingEmailsPage = () => {
  const [emails, setEmails] = useState<ApiOutgoingEmail[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<ApiOutgoingEmail | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState<"send" | "schedule" | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [editingTime, setEditingTime] = useState(false);
  const [timeValue, setTimeValue] = useState("");

  const load = useCallback(() => {
    setLoading(true);
    api
      .getOutgoingEmails()
      .then((res) => {
        const r = res as { data?: { emails?: ApiOutgoingEmail[] } };
        const list = r?.data?.emails ?? [];
        setEmails(list);
        setSelectedId((current) =>
          current && list.some((e) => e.id === current)
            ? current
            : (list[0]?.id ?? null),
        );
      })
      .catch((e: unknown) => setError(e instanceof Error ? e.message : "Error"))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      return;
    }
    let active = true;
    api
      .getOutgoingEmail(selectedId)
      .then((res) => {
        if (active) setDetail((res as { data: ApiOutgoingEmail }).data);
      })
      .catch((e: unknown) => {
        if (active) setError(e instanceof Error ? e.message : "Error");
      });
    return () => {
      active = false;
    };
  }, [selectedId, reloadKey]);

  const selectEmail = (id: string) => {
    setSelectedId(id);
    setEditingTime(false);
    setNotice(null);
  };

  const run = async (action: () => Promise<unknown>, success?: string) => {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await action();
      if (success) setNotice(success);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Error");
    } finally {
      setBusy(false);
      load();
      setReloadKey((k) => k + 1);
    }
  };

  const scheduleWithMessage = async (id: string, scheduledFor?: string) => {
    const res = (await api.scheduleOutgoingEmail(id, scheduledFor)) as {
      data?: ApiOutgoingEmail;
    } | null;
    const when = res?.data?.scheduledFor;
    setNotice(
      when
        ? `Listo: el correo quedó programado y sale el ${formatDateAR(when)}.`
        : "Listo: el correo quedó programado.",
    );
  };

  const saveTime = () => {
    if (!detail || !timeValue) return;
    setEditingTime(false);
    run(() => scheduleWithMessage(detail.id, `${timeValue}:00${AR_OFFSET}`));
  };

  const downloadReceipt = async (requestId: string) => {
    try {
      await api.downloadRequestReceipt(requestId);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Error");
    }
  };

  return (
    <div>
      <h2 className="text-3xl text-t-primary">Correos para enviar</h2>
      <p className="mt-1 text-sm text-t-muted">
        Revisá el mail y el comprobante adjunto. Nada se envía al inversor hasta
        que toques Enviar.
      </p>

      {error ? <p className="mt-4 text-sm text-error">{error}</p> : null}
      {notice ? (
        <p className="mt-4 text-sm text-success" role="status">
          {notice}
        </p>
      ) : null}

      {loading && emails.length === 0 ? (
        <p className="mt-6 text-t-muted">Cargando...</p>
      ) : emails.length === 0 ? (
        <div className="admin-card mt-6 p-6 text-t-muted">
          No hay correos pendientes.
        </div>
      ) : (
        <div className="mt-6 grid gap-6 lg:grid-cols-[340px_1fr]">
          <ul className="space-y-3">
            {emails.map((e) => (
              <li key={e.id}>
                <button
                  type="button"
                  onClick={() => selectEmail(e.id)}
                  className={`admin-card w-full p-4 text-left ${
                    e.id === selectedId ? "border-primary" : ""
                  }`}
                >
                  <p className="text-xs font-semibold uppercase tracking-wider text-primary">
                    {KIND_LABELS[e.kind] ?? e.kind}
                  </p>
                  <p className="mt-1 font-medium text-t-primary">
                    {e.investor.name}
                  </p>
                  <p className="text-xs text-t-muted">
                    {STATUS_LABELS[e.status] ?? e.status}
                    {e.scheduledFor
                      ? ` · Sale ${formatDateAR(e.scheduledFor)}`
                      : ` · ${formatDateAR(e.createdAt)}`}
                  </p>
                </button>
              </li>
            ))}
          </ul>

          {detail ? (
            <div className="admin-card p-6">
              <dl className="grid gap-2 text-sm sm:grid-cols-[90px_1fr]">
                <dt className="text-t-muted">Para</dt>
                <dd className="text-t-primary">{detail.to}</dd>
                <dt className="text-t-muted">Asunto</dt>
                <dd className="text-t-primary">{detail.subject}</dd>
                {detail.scheduledFor ? (
                  <>
                    <dt className="text-t-muted">Salida</dt>
                    <dd className="text-t-primary">
                      {formatDateAR(detail.scheduledFor)}
                      {detail.status === "SCHEDULED" ? null : (
                        <span className="text-t-muted">
                          {" "}
                          (sugerida, se programa al confirmar)
                        </span>
                      )}
                    </dd>
                  </>
                ) : null}
                {detail.hasReceipt && detail.requestId ? (
                  <>
                    <dt className="text-t-muted">Adjunto</dt>
                    <dd>
                      <button
                        type="button"
                        className="text-primary underline"
                        onClick={() => downloadReceipt(detail.requestId!)}
                      >
                        {detail.receiptFilename}
                      </button>
                    </dd>
                  </>
                ) : null}
              </dl>

              {detail.status === "SCHEDULED" && detail.scheduledFor ? (
                <div className="mt-4 rounded-lg border border-b-accent bg-primary-dim px-4 py-3 text-sm text-t-primary">
                  <strong className="text-success">Programado.</strong> Sale
                  solo el {formatDateAR(detail.scheduledFor)}. No hace falta
                  hacer nada más.
                </div>
              ) : null}

              {editingTime ? (
                <div className="mt-4 flex flex-wrap items-end gap-2">
                  <label className="text-sm text-t-muted">
                    Fecha y hora de envío (hora de Argentina)
                    <input
                      type="datetime-local"
                      aria-label="Fecha y hora de envío"
                      value={timeValue}
                      onChange={(e) => setTimeValue(e.target.value)}
                      className="mt-1 block rounded-lg border border-b-default bg-dark-section px-3 py-2 text-t-primary"
                    />
                  </label>
                  <Button disabled={busy || !timeValue} onClick={saveTime}>
                    Guardar
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => setEditingTime(false)}
                  >
                    Cancelar
                  </Button>
                </div>
              ) : null}

              {detail.error ? (
                <p className="mt-3 text-sm text-error">{detail.error}</p>
              ) : null}

              <iframe
                title="Vista previa del correo"
                sandbox=""
                srcDoc={detail.bodyHtml}
                className="mt-4 h-[520px] w-full rounded-lg border border-b-default bg-white"
              />

              <div className="mt-4 flex flex-wrap gap-2">
                {detail.status === "SCHEDULED" ? (
                  <Button
                    disabled={busy}
                    onClick={() =>
                      run(
                        () => api.unscheduleOutgoingEmail(detail.id),
                        "Programación cancelada: el correo volvió a quedar para revisar.",
                      )
                    }
                  >
                    Cancelar programación
                  </Button>
                ) : (
                  <Button
                    disabled={busy}
                    onClick={() => setConfirm("schedule")}
                  >
                    Programar envío
                  </Button>
                )}
                <Button
                  variant="outline"
                  disabled={busy}
                  onClick={() => {
                    setTimeValue(toArInput(detail.scheduledFor));
                    setEditingTime(true);
                  }}
                >
                  Modificar fecha y hora
                </Button>
                <Button
                  variant="outline"
                  disabled={busy}
                  onClick={() => setConfirm("send")}
                >
                  Enviar ahora
                </Button>
                {detail.hasReceipt ? (
                  <Button
                    variant="outline"
                    disabled={busy}
                    onClick={() =>
                      run(
                        () => api.regenerateOutgoingEmail(detail.id),
                        "Listo: el correo y el comprobante se actualizaron al formato vigente.",
                      )
                    }
                  >
                    Actualizar formato
                  </Button>
                ) : null}
                <Button
                  variant="outline"
                  disabled={busy}
                  onClick={() =>
                    run(
                      () => api.discardOutgoingEmail(detail.id),
                      "Correo descartado.",
                    )
                  }
                >
                  Descartar
                </Button>
              </div>
            </div>
          ) : null}
        </div>
      )}

      <ConfirmDialog
        isOpen={confirm !== null}
        onClose={() => setConfirm(null)}
        onConfirm={() => {
          if (!detail) return;
          if (confirm === "schedule") {
            run(() => scheduleWithMessage(detail.id));
          } else {
            run(() => api.sendOutgoingEmail(detail.id), "Correo enviado.");
          }
        }}
        title={confirm === "schedule" ? "Programar envío" : "Enviar ahora"}
        message={
          confirm === "schedule"
            ? `Saldrá automáticamente a ${detail?.to ?? ""}${
                detail?.scheduledFor
                  ? ` el ${formatDateAR(detail.scheduledFor)}`
                  : ""
              }${
                detail?.hasReceipt ? " con el comprobante adjunto" : ""
              }. ¿Confirmás?`
            : `Se enviará ahora mismo a ${detail?.to ?? ""}${
                detail?.hasReceipt ? " con el comprobante adjunto" : ""
              }. ¿Confirmás?`
        }
        confirmText={confirm === "schedule" ? "Programar" : "Enviar ahora"}
        confirmVariant="primary"
      />
    </div>
  );
};
