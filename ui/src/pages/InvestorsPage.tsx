import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { formatCurrencyAR } from "../lib/formatters";
import type { ApiInvestor } from "../types";

const frequencyLabel = (freq: string) => {
  if (freq === "MONTHLY") return "Mensual";
  if (freq === "ANNUAL") return "Anual";
  if (freq === "SEMESTRAL") return "Semestral";
  return "Trimestral";
};

export const InvestorsPage = () => {
  const navigate = useNavigate();
  const [data, setData] = useState<{ data?: ApiInvestor[] } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    email: "",
    name: "",
    tradingFeePercentage: "30",
    password: "",
  });
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState<{
    isOpen: boolean;
    investor: ApiInvestor | null;
  }>({
    isOpen: false,
    investor: null,
  });

  const fetchInvestors = () => {
    api
      .getAdminInvestors({})
      .then((res) => setData(res))
      .catch((e) => setError(e.message));
  };

  useEffect(() => {
    fetchInvestors();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const pct = Number(formData.tradingFeePercentage);
      if (!Number.isFinite(pct) || pct <= 0 || pct > 100) {
        alert("El porcentaje debe estar entre 0 y 100");
        return;
      }

      const { password, tradingFeePercentage, ...rest } = formData;
      const payload = {
        ...rest,
        trading_fee_percentage: Number(tradingFeePercentage),
      };

      await api.createInvestor(password ? { ...payload, password } : payload);
      setFormData({
        email: "",
        name: "",
        tradingFeePercentage: "30",
        password: "",
      });
      setShowPassword(false);
      setShowForm(false);
      fetchInvestors();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Error al crear inversor");
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = (investor: ApiInvestor) => {
    setDeleteConfirm({ isOpen: true, investor });
  };

  const confirmDelete = async () => {
    if (!deleteConfirm.investor) return;
    try {
      await api.deleteInvestor(deleteConfirm.investor.id);
      fetchInvestors();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Error al eliminar inversor");
    }
  };

  const handleToggleStatus = async (investor: ApiInvestor) => {
    try {
      await api.toggleInvestorStatus(investor.id);
      fetchInvestors();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Error al cambiar status");
    }
  };

  if (error) return <div className="text-error">{error}</div>;
  if (!data) return <div className="text-t-muted">Cargando...</div>;

  const investors: ApiInvestor[] = data?.data ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-2 md:gap-4">
        <h1 className="text-3xl font-bold text-t-primary">Inversores</h1>
        <Button
          onClick={() => setShowForm(!showForm)}
          className="shrink-0 text-xs md:text-sm px-2 py-1.5 md:px-4 md:py-2"
        >
          {showForm ? "Cancelar" : "+ Agregar Inversor"}
        </Button>
      </div>

      {showForm && (
        <div className="admin-card p-6">
          <h2 className="text-lg font-semibold text-t-primary mb-4">
            Nuevo Inversor
          </h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
                <label className="block text-sm font-medium text-t-muted mb-1">
                Email *
              </label>
              <Input
                type="email"
                required
                value={formData.email}
                onChange={(e) =>
                  setFormData({ ...formData, email: e.target.value })
                }
                placeholder="inversor@ejemplo.com"
              />
            </div>
            <div>
                <label className="block text-sm font-medium text-t-muted mb-1">
                Nombre *
              </label>
              <Input
                type="text"
                required
                value={formData.name}
                onChange={(e) =>
                  setFormData({ ...formData, name: e.target.value })
                }
                placeholder="María González"
              />
            </div>
            <div>
                <label className="block text-sm font-medium text-t-muted mb-1">
                Trading fee (%)
              </label>
              <Input
                type="number"
                min={0}
                max={100}
                step="0.1"
                value={formData.tradingFeePercentage}
                onChange={(e) =>
                  setFormData({
                    ...formData,
                    tradingFeePercentage: e.target.value,
                  })
                }
                placeholder="30"
              />
              <p className="mt-1 text-xs text-t-dim">
                Default 30%. Podés editarlo por inversor.
              </p>
            </div>
            <div>
                <label className="block text-sm font-medium text-t-muted mb-1">
                Contraseña
              </label>
              <div className="relative">
                <Input
                  type={showPassword ? "text" : "password"}
                  value={formData.password}
                  onChange={(e) =>
                    setFormData({ ...formData, password: e.target.value })
                  }
                  placeholder="Mínimo 6 caracteres"
                  minLength={6}
                  className="pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-t-dim hover:text-t-primary focus:outline-none focus:ring-2 focus:ring-primary"
                  title={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
                  aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
                >
                  {showPassword ? (
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden>
                      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </svg>
                  ) : (
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden>
                      <path d="M2.5 12s3.5-7 9.5-7 9.5 7 9.5 7-3.5 7-9.5 7-9.5-7-9.5-7Z" />
                      <path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z" />
                    </svg>
                  )}
                </button>
              </div>
              <p className="mt-1 text-xs text-t-dim">
                Opcional. Si no se establece, el inversor solo podrá acceder con
                Google.
              </p>
            </div>
            <div className="flex gap-3">
              <Button type="submit" disabled={submitting}>
                {submitting ? "Creando..." : "Crear Inversor"}
              </Button>
              <Button
                type="button"
                onClick={() => setShowForm(false)}
                className="bg-dark-section hover:bg-primary-dim"
              >
                Cancelar
              </Button>
            </div>
          </form>
        </div>
      )}

      {/* Mobile: cards */}
      <div className="grid gap-3 px-1 md:hidden">
        {investors.map((inv) => (
          <div
            key={inv.id}
            className="w-full overflow-hidden admin-card p-4"
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-t-primary">
                  {inv.name}
                </p>
                <p className="truncate mt-1 text-sm text-t-muted">
                  {inv.email}
                </p>
              </div>
              <button
                onClick={() => handleToggleStatus(inv)}
                className={`shrink-0 inline-flex rounded-full px-2 py-0.5 text-[11px] font-semibold cursor-pointer ${
                  inv.status === "ACTIVE"
                    ? "bg-success/15 text-success"
                    : "bg-error/15 text-error"
                }`}
                title={inv.status === "ACTIVE" ? "Desactivar" : "Activar"}
              >
                {inv.status === "ACTIVE" ? "Activo" : "Inactivo"}
              </button>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-3 text-sm">
              <div>
                <p className="text-xs text-t-dim">Capital Actual</p>
                <p className="mt-1 font-mono font-semibold text-t-primary">
                  {formatCurrencyAR(inv.portfolio?.currentBalance ?? 0)}
                </p>
              </div>
              <div>
                <p className="text-xs text-t-dim">Total Invertido</p>
                <p className="mt-1 font-mono font-semibold text-t-primary">
                  {formatCurrencyAR(inv.portfolio?.totalInvested ?? 0)}
                </p>
              </div>
            </div>
            <div className="mt-2 flex items-center justify-between text-xs text-t-dim">
              <span>
                Fee: {frequencyLabel(inv.tradingFeeFrequency ?? "QUARTERLY")} (
                {inv.tradingFeePercentage ?? 30}%)
              </span>
              <span>{inv.hasPassword ? "🔑 Pass" : "Google"}</span>
            </div>
            <div className="mt-3 flex gap-2">
              <button
                onClick={() => navigate(`/investors/${String(inv.id)}/edit`)}
                className="rounded p-2 text-primary hover:bg-primary-dim"
                title="Editar"
              >
                <svg
                  className="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
                  />
                </svg>
              </button>
              <button
                onClick={() => handleDelete(inv)}
                className="p-2 text-error hover:bg-error/15 rounded"
                title="Eliminar"
              >
                <svg
                  className="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                  />
                </svg>
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Desktop/tablet: table */}
      <div className="hidden md:block admin-card p-6">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead>
              <tr className="text-left text-sm text-t-dim border-b border-b-default">
                <th className="pb-3 pr-4">Nombre</th>
                <th className="pb-3 pr-4">Email</th>
                <th className="pb-3 pr-4 text-center">Status</th>
                <th className="pb-3 pr-4 text-right">Capital Actual</th>
                <th className="pb-3 pr-4 text-center">Fee</th>
                <th className="pb-3 pr-4 text-center">Auth</th>
                <th className="pb-3 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-b-default">
              {investors.map((inv) => (
                <tr
                  key={inv.id}
                  className={`text-sm ${inv.status === "INACTIVE" ? "opacity-50" : ""}`}
                >
                  <td className="py-3 pr-4 font-medium">{inv.name}</td>
                  <td className="py-3 pr-4 text-t-muted">{inv.email}</td>
                  <td className="py-3 pr-4 text-center">
                    <button
                      onClick={() => handleToggleStatus(inv)}
                      className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold cursor-pointer transition-colors ${
                        inv.status === "ACTIVE"
                          ? "bg-success/15 text-success"
                          : "bg-error/15 text-error"
                      }`}
                      title={
                        inv.status === "ACTIVE"
                          ? "Click para desactivar"
                          : "Click para activar"
                      }
                    >
                      {inv.status === "ACTIVE" ? "Activo" : "Inactivo"}
                    </button>
                  </td>
                  <td className="py-3 pr-4 text-right font-mono text-t-primary">
                    {formatCurrencyAR(inv.portfolio?.currentBalance ?? 0)}
                  </td>
                  <td className="py-3 pr-4 text-center">
                    <span className="inline-flex rounded-full bg-info/15 px-2 py-0.5 text-xs font-semibold text-info">
                      {frequencyLabel(inv.tradingFeeFrequency ?? "QUARTERLY")} (
                      {inv.tradingFeePercentage ?? 30}%)
                    </span>
                  </td>
                  <td className="py-3 pr-4 text-center">
                    {inv.hasPassword ? (
                      <span
                        className="inline-flex items-center gap-1 rounded-full bg-info/15 px-2 py-0.5 text-xs font-semibold text-info"
                        title="Contraseña configurada"
                      >
                        🔑
                      </span>
                    ) : (
                      <span className="text-xs text-t-dim">Google</span>
                    )}
                  </td>
                  <td className="py-3 text-right">
                    <div className="flex gap-1 justify-end">
                      <button
                        onClick={() =>
                          navigate(`/investors/${String(inv.id)}/edit`)
                        }
                        className="rounded p-1.5 text-primary hover:bg-primary-dim"
                        title="Editar"
                      >
                        <svg
                          className="w-4 h-4"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
                          />
                        </svg>
                      </button>
                      <button
                        onClick={() => handleDelete(inv)}
                        className="p-1.5 text-error hover:bg-error/15 rounded"
                        title="Eliminar"
                      >
                        <svg
                          className="w-4 h-4"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                          />
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <ConfirmDialog
        isOpen={deleteConfirm.isOpen}
        onClose={() => setDeleteConfirm({ isOpen: false, investor: null })}
        onConfirm={confirmDelete}
        title="Eliminar Inversor"
        message={
          deleteConfirm.investor ? (
            <>
              ¿Estás seguro de eliminar a{" "}
              <span className="font-semibold">
                {deleteConfirm.investor.name}
              </span>
              ?
              <br />
              <span className="text-error">
                Esta acción no se puede deshacer.
              </span>
            </>
          ) : (
            ""
          )
        }
        confirmText="Eliminar"
        cancelText="Cancelar"
        confirmVariant="danger"
      />
    </div>
  );
};
