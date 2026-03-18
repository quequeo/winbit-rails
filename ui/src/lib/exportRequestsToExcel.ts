import * as XLSX from "xlsx";
import { formatCurrencyAR, formatDateAR } from "./formatters";
import type { ApiRequest } from "../types";

const STATUS_LABELS: Record<string, string> = {
  PENDING: "Pendiente",
  APPROVED: "Aprobado",
  REJECTED: "Rechazado",
  REVERSED: "Revertido",
};

const TYPE_LABELS: Record<string, string> = {
  DEPOSIT: "Depósito",
  WITHDRAWAL: "Retiro",
};

const METHOD_LABELS: Record<string, string> = {
  USDT: "USDT",
  USDC: "USDC",
  CASH: "Efectivo",
  CASH_USD: "Efectivo USD",
  LEMON_CASH: "Lemon Cash",
  SWIFT: "SWIFT",
  CRYPTO: "Cripto",
};

export const exportRequestsToExcel = (requests: ApiRequest[]): void => {
  const rows = requests.map((r) => ({
    Inversor: r.investor?.name ?? "",
    Email: r.investor?.email ?? "",
    Tipo: TYPE_LABELS[r.type] ?? r.type,
    Método: METHOD_LABELS[r.method] ?? r.method,
    Monto: formatCurrencyAR(Number(r.amount)),
    Estado: STATUS_LABELS[r.status] ?? r.status,
    "Fecha solicitud": r.requestedAt ? formatDateAR(r.requestedAt) : "",
    "Fecha procesamiento": r.processedAt ? formatDateAR(r.processedAt) : "",
  }));

  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Solicitudes");

  const dateStr = new Date().toISOString().slice(0, 10);
  XLSX.writeFile(wb, `solicitudes_${dateStr}.xlsx`);
};
