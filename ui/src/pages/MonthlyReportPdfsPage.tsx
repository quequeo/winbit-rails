import { useEffect, useMemo, useRef, useState } from "react";
import { api } from "../lib/api";
import { lastClosedMonth } from "../lib/lastClosedMonth";
import { Button } from "../components/ui/Button";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";

type InvestorRow = {
  id: string;
  name: string;
  email: string;
  status: string;
};

type PresentRow = {
  id: string;
  month: string;
  originalFilename: string;
  byteSize: number;
  uploadedAt?: string;
  investor: InvestorRow;
};

type IndexPayload = {
  month: string;
  present: PresentRow[];
  missing: InvestorRow[];
  counts: {
    present: number;
    missing: number;
    missingActive: number;
  };
};

type AssignmentRow = {
  filename: string;
  parsedName?: string | null;
  status: "assign" | "replace" | "skip";
  reason?: string | null;
  alreadyHasPdf?: boolean;
  investor?: InvestorRow | null;
};

type PreviewPayload = {
  preview: boolean;
  assignments: AssignmentRow[];
  counts: { assign: number; replace: number; skip: number };
  uploaded_count?: number;
  replaced_count?: number;
};

const SKIP_REASONS: Record<string, string> = {
  not_pdf: "No es un PDF",
  too_large: "Supera 15MB",
  empty: "Archivo vacío",
  unparseable_filename:
    'Nombre no reconocido. Usá "Reporte julio - NOMBRE APELLIDO.pdf"',
  unknown_month: "Mes no reconocido en el nombre",
  missing_name: "Falta el nombre en el archivo",
  month_mismatch: "El mes del archivo no coincide con el mes seleccionado",
  year_mismatch: "El año del archivo no coincide",
  investor_not_found: "No hay inversor con ese nombre",
  ambiguous_name: "Hay más de un inversor con ese nombre",
  override_investor_not_found: "El email de override no existe",
};

const STATUS_LABELS: Record<AssignmentRow["status"], string> = {
  assign: "Asignar",
  replace: "Reemplazar",
  skip: "Omitido",
};

const formatBytes = (n: number) => {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
};

const skipLabel = (reason: string) => SKIP_REASONS[reason] || reason;

export const MonthlyReportPdfsPage = () => {
  const [month, setMonth] = useState(lastClosedMonth);
  const [data, setData] = useState<IndexPayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [preview, setPreview] = useState<PreviewPayload | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<PresentRow | null>(null);
  const bulkInputRef = useRef<HTMLInputElement>(null);
  const singleInputRef = useRef<HTMLInputElement>(null);
  const [singleInvestorId, setSingleInvestorId] = useState<string | null>(null);

  const fetchMonth = (value: string) => {
    setError(null);
    api
      .getMonthlyReportPdfs(value)
      .then((res) => {
        const payload = (res as { data: IndexPayload }).data;
        setData(payload);
      })
      .catch((e: Error) => setError(e.message));
  };

  useEffect(() => {
    fetchMonth(month);
  }, [month]);

  const persistableCount = useMemo(() => {
    if (!preview) return 0;
    return preview.counts.assign + preview.counts.replace;
  }, [preview]);

  const handleBulkFiles = async (files: FileList | null) => {
    if (!files?.length) return;
    const list = Array.from(files);
    setUploading(true);
    setNotice(null);
    setPreview(null);
    try {
      const res = await api.uploadMonthlyReportPdfs({
        month,
        files: list,
        preview: true,
      });
      const payload = (res as { data: PreviewPayload }).data;
      setPendingFiles(list);
      setPreview(payload);
      setNotice(
        persistableFrom(payload)
          ? "Revisá las asignaciones y confirmá para guardar."
          : "Ningún archivo se puede asignar. Revisá los omitidos.",
      );
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error al analizar PDFs");
    } finally {
      setUploading(false);
      if (bulkInputRef.current) bulkInputRef.current.value = "";
    }
  };

  const persistableFrom = (payload: PreviewPayload) =>
    payload.counts.assign + payload.counts.replace;

  const handleConfirmPreview = async () => {
    if (!pendingFiles.length) return;
    setUploading(true);
    setError(null);
    try {
      const res = await api.uploadMonthlyReportPdfs({
        month,
        files: pendingFiles,
        preview: false,
        confirm: true,
      });
      const summary = (res as { data: PreviewPayload }).data;
      const parts = [];
      if (summary.uploaded_count)
        parts.push(`${summary.uploaded_count} nuevos`);
      if (summary.replaced_count)
        parts.push(`${summary.replaced_count} reemplazados`);
      setNotice(
        parts.length ? `Carga lista: ${parts.join(", ")}.` : "Nada se guardó.",
      );
      setPreview(null);
      setPendingFiles([]);
      fetchMonth(month);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error al guardar PDFs");
    } finally {
      setUploading(false);
    }
  };

  const handleCancelPreview = () => {
    setPreview(null);
    setPendingFiles([]);
    setNotice(null);
  };

  const handleSingleFile = async (files: FileList | null) => {
    const file = files?.[0];
    if (!file || !singleInvestorId) return;
    setUploading(true);
    setNotice(null);
    try {
      await api.uploadMonthlyReportPdfs({
        month,
        files: [file],
        investorId: singleInvestorId,
      });
      setNotice("PDF asignado.");
      fetchMonth(month);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error al subir PDF");
    } finally {
      setUploading(false);
      setSingleInvestorId(null);
      if (singleInputRef.current) singleInputRef.current.value = "";
    }
  };

  const handleDownload = async (row: PresentRow) => {
    try {
      await api.downloadMonthlyReportPdfFile(row.id, row.originalFilename);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error al descargar");
    }
  };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    try {
      await api.deleteMonthlyReportPdf(deleteTarget.id);
      setNotice("PDF eliminado.");
      fetchMonth(month);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Error al eliminar");
    }
  };

  const missingActive = useMemo(
    () => (data?.missing || []).filter((row) => row.status === "ACTIVE"),
    [data],
  );
  const missingInactive = useMemo(
    () => (data?.missing || []).filter((row) => row.status !== "ACTIVE"),
    [data],
  );

  if (error && !data) return <div className="text-error">{error}</div>;
  if (!data) return <div className="text-t-muted">Cargando...</div>;

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-t-primary">Reportes PDF</h1>
          <p className="mt-1 text-sm text-t-muted">
            Cargá los PDFs del mes cerrado. Primero se muestra a quién se
            asignaría cada archivo; no se guarda hasta que confirmes. Nombre
            esperado:{" "}
            <span className="text-t-primary">
              Reporte julio - TULIO CAPPARELLI.pdf
            </span>
          </p>
        </div>
        <label className="flex items-center gap-2 text-sm text-t-muted">
          Mes
          <input
            type="month"
            value={month}
            onChange={(e) => setMonth(e.target.value)}
            aria-label="Mes del reporte"
          />
        </label>
      </div>

      {error ? <div className="text-sm text-error">{error}</div> : null}
      {notice ? <div className="text-sm text-success">{notice}</div> : null}

      <div className="admin-card p-6 space-y-4">
        <div className="flex flex-wrap items-center gap-3">
          <Button
            type="button"
            onClick={() => bulkInputRef.current?.click()}
            disabled={uploading}
          >
            {uploading ? "Analizando..." : "Elegir PDFs o ZIP"}
          </Button>
          <input
            ref={bulkInputRef}
            type="file"
            accept=".pdf,.zip,application/pdf,application/zip"
            multiple
            className="hidden"
            onChange={(e) => handleBulkFiles(e.target.files)}
          />
          <p className="text-sm text-t-muted">
            Varios PDF o un ZIP. Máx. 15MB por archivo. El mes del nombre tiene
            que coincidir con el mes seleccionado.
          </p>
        </div>
        <div className="flex flex-wrap gap-4 text-sm">
          <span className="text-success">Con PDF: {data.counts.present}</span>
          <span className="text-warning">
            Faltan (activos): {data.counts.missingActive}
          </span>
          <span className="text-t-muted">
            Faltan total: {data.counts.missing}
          </span>
        </div>
      </div>

      {preview ? (
        <div className="admin-card overflow-x-auto p-6 space-y-4">
          <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <h2 className="text-lg font-semibold text-t-primary">
              Revisión ({preview.assignments.length})
            </h2>
            <div className="flex flex-wrap gap-2">
              <Button
                type="button"
                variant="outline"
                onClick={handleCancelPreview}
                disabled={uploading}
              >
                Cancelar
              </Button>
              <Button
                type="button"
                onClick={handleConfirmPreview}
                disabled={uploading || persistableCount === 0}
              >
                {uploading
                  ? "Guardando..."
                  : `Confirmar ${persistableCount} PDF${persistableCount === 1 ? "" : "s"}`}
              </Button>
            </div>
          </div>
          <div className="flex flex-wrap gap-4 text-sm">
            <span className="text-success">
              Asignar: {preview.counts.assign}
            </span>
            <span className="text-warning">
              Reemplazar: {preview.counts.replace}
            </span>
            <span className="text-t-muted">Omitidos: {preview.counts.skip}</span>
          </div>
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="text-t-dim">
                <th className="pb-2 font-medium">Archivo</th>
                <th className="pb-2 font-medium">Nombre leído</th>
                <th className="pb-2 font-medium">Inversor</th>
                <th className="pb-2 font-medium">Estado</th>
              </tr>
            </thead>
            <tbody>
              {preview.assignments.map((row) => (
                <tr
                  key={`${row.filename}-${row.status}-${row.reason || ""}`}
                  className="border-t border-b-default"
                >
                  <td className="py-2 text-t-primary">{row.filename}</td>
                  <td className="py-2 text-t-muted">{row.parsedName || "—"}</td>
                  <td className="py-2 text-t-muted">
                    {row.investor
                      ? `${row.investor.name} (${row.investor.email})`
                      : "—"}
                  </td>
                  <td className="py-2">
                    {row.status === "skip" ? (
                      <span className="text-error">
                        Omitido — {skipLabel(row.reason || "")}
                      </span>
                    ) : (
                      <span
                        className={
                          row.status === "replace"
                            ? "text-warning"
                            : "text-success"
                        }
                      >
                        {STATUS_LABELS[row.status]}
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}

      <div className="admin-card overflow-x-auto p-6">
        <h2 className="mb-3 text-lg font-semibold text-t-primary">
          Con PDF ({data.present.length})
        </h2>
        {data.present.length === 0 ? (
          <p className="text-sm text-t-muted">Nadie tiene PDF para este mes.</p>
        ) : (
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="text-t-dim">
                <th className="pb-2 font-medium">Inversor</th>
                <th className="pb-2 font-medium">Email</th>
                <th className="pb-2 font-medium">Archivo</th>
                <th className="pb-2 font-medium">Tamaño</th>
                <th className="pb-2 font-medium" />
              </tr>
            </thead>
            <tbody>
              {data.present.map((row) => (
                <tr key={row.id} className="border-t border-b-default">
                  <td className="py-2 text-t-primary">{row.investor.name}</td>
                  <td className="py-2 text-t-muted">{row.investor.email}</td>
                  <td className="py-2 text-t-muted">{row.originalFilename}</td>
                  <td className="py-2 text-t-muted">
                    {formatBytes(row.byteSize)}
                  </td>
                  <td className="py-2 text-right">
                    <div className="flex justify-end gap-2">
                      <Button
                        type="button"
                        size="sm"
                        variant="outline"
                        onClick={() => handleDownload(row)}
                      >
                        Ver
                      </Button>
                      <Button
                        type="button"
                        size="sm"
                        variant="destructive"
                        onClick={() => setDeleteTarget(row)}
                      >
                        Quitar
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="admin-card overflow-x-auto p-6">
        <h2 className="mb-3 text-lg font-semibold text-t-primary">
          Faltan ({missingActive.length} activos)
        </h2>
        {missingActive.length === 0 ? (
          <p className="text-sm text-t-muted">Todos los activos tienen PDF.</p>
        ) : (
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="text-t-dim">
                <th className="pb-2 font-medium">Inversor</th>
                <th className="pb-2 font-medium">Email</th>
                <th className="pb-2 font-medium" />
              </tr>
            </thead>
            <tbody>
              {missingActive.map((row) => (
                <tr key={row.id} className="border-t border-b-default">
                  <td className="py-2 text-t-primary">{row.name}</td>
                  <td className="py-2 text-t-muted">{row.email}</td>
                  <td className="py-2 text-right">
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      onClick={() => {
                        setSingleInvestorId(row.id);
                        singleInputRef.current?.click();
                      }}
                      disabled={uploading}
                    >
                      Subir
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {missingInactive.length > 0 ? (
          <p className="mt-3 text-xs text-t-dim">
            También faltan {missingInactive.length} inversores inactivos (no se
            listan; el portal no les sirve el PDF).
          </p>
        ) : null}
        <input
          ref={singleInputRef}
          type="file"
          accept=".pdf,application/pdf"
          className="hidden"
          onChange={(e) => handleSingleFile(e.target.files)}
        />
      </div>

      <ConfirmDialog
        isOpen={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={confirmDelete}
        title="Quitar PDF"
        message={
          deleteTarget
            ? `¿Eliminar el PDF de ${deleteTarget.investor.name} para ${month}?`
            : ""
        }
        confirmText="Quitar"
      />
    </div>
  );
};
