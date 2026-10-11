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
  DRAFT: "Para enviar",
  FAILED: "Falló el envío",
  SENT: "Enviado",
  DISCARDED: "Descartado",
};

export const OutgoingEmailsPage = () => {
  const [emails, setEmails] = useState<ApiOutgoingEmail[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<ApiOutgoingEmail | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirmSend, setConfirmSend] = useState(false);

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
      .catch((e: unknown) =>
        setError(e instanceof Error ? e.message : "Error"),
      )
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
  }, [selectedId]);

  const run = async (action: () => Promise<unknown>) => {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Error");
    } finally {
      setBusy(false);
      load();
    }
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
                  onClick={() => setSelectedId(e.id)}
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
                    {formatDateAR(e.createdAt)} ·{" "}
                    {STATUS_LABELS[e.status] ?? e.status}
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

              {detail.error ? (
                <p className="mt-3 text-sm text-error">{detail.error}</p>
              ) : null}

              <iframe
                title="Vista previa del correo"
                sandbox=""
                srcDoc={detail.bodyHtml}
                className="mt-4 h-[520px] w-full rounded-lg border border-b-default bg-white"
              />

              <div className="mt-4 flex gap-2">
                <Button disabled={busy} onClick={() => setConfirmSend(true)}>
                  Enviar
                </Button>
                <Button
                  variant="outline"
                  disabled={busy}
                  onClick={() => run(() => api.discardOutgoingEmail(detail.id))}
                >
                  Descartar
                </Button>
              </div>
            </div>
          ) : null}
        </div>
      )}

      <ConfirmDialog
        isOpen={confirmSend}
        onClose={() => setConfirmSend(false)}
        onConfirm={() => detail && run(() => api.sendOutgoingEmail(detail.id))}
        title="Enviar correo"
        message={`Se enviará a ${detail?.to ?? ""}${
          detail?.hasReceipt ? " con el comprobante adjunto" : ""
        }. ¿Confirmás?`}
        confirmText="Enviar"
        confirmVariant="primary"
      />
    </div>
  );
};
