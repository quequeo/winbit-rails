import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "../lib/api";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";
import { Select } from "../components/ui/Select";
import type { ApiInvestor } from "../types";

export const EditInvestorPage = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [investor, setInvestor] = useState<ApiInvestor | null>(null);
  const [form, setForm] = useState({
    email: "",
    name: "",
    status: "ACTIVE" as "ACTIVE" | "INACTIVE",
    tradingFeeFrequency: "QUARTERLY" as
      | "MONTHLY"
      | "QUARTERLY"
      | "SEMESTRAL"
      | "ANNUAL",
    tradingFeePercentage: "30",
    newPassword: "",
  });

  useEffect(() => {
    api
      .getAdminInvestors({})
      .then((res) => {
        const data = (res as { data?: ApiInvestor[] } | null)?.data;
        const inv = data?.find((i) => String(i.id) === id);
        if (inv) {
          setInvestor(inv);
          setForm({
            email: inv.email ?? "",
            name: inv.name ?? "",
            status: (inv.status === "INACTIVE" ? "INACTIVE" : "ACTIVE") as
              | "ACTIVE"
              | "INACTIVE",
            tradingFeeFrequency: (inv.tradingFeeFrequency ?? "QUARTERLY") as
              | "MONTHLY"
              | "QUARTERLY"
              | "SEMESTRAL"
              | "ANNUAL",
            tradingFeePercentage: String(inv.tradingFeePercentage ?? 30),
            newPassword: "",
          });
        } else {
          setError("Inversor no encontrado");
        }
        setLoading(false);
      })
      .catch((e) => {
        setError(e.message);
        setLoading(false);
      });
  }, [id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!id) return;
    setSubmitting(true);
    try {
      const pct = Number(form.tradingFeePercentage);
      if (!Number.isFinite(pct) || pct <= 0 || pct > 100) {
        alert("El porcentaje debe estar entre 0 y 100");
        return;
      }

      const body: Parameters<typeof api.updateInvestor>[1] = {
        email: form.email,
        name: form.name,
        status: form.status,
        trading_fee_frequency: form.tradingFeeFrequency,
        trading_fee_percentage: pct,
      };
      if (form.newPassword) body.password = form.newPassword;
      await api.updateInvestor(id, body);
      navigate("/investors");
    } catch (err: unknown) {
      alert(
        err instanceof Error ? err.message : "Error al actualizar inversor",
      );
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <div className="text-t-muted">Cargando...</div>;
  if (error) return <div className="text-error">{error}</div>;

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div className="flex items-center gap-4">
        <button
          onClick={() => navigate("/investors")}
          className="text-t-dim hover:text-t-muted"
        >
          <svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M15 19l-7-7 7-7"
            />
          </svg>
        </button>
        <h1 className="text-2xl font-bold text-t-primary">Editar Inversor</h1>
      </div>

      <div className="rounded-lg bg-dark-card p-6">
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-t-muted mb-1">
              Email *
            </label>
            <Input
              type="email"
              required
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
            <p className="mt-1 text-xs text-warning">
              Cambiar el email puede impedir que el inversor inicie sesión en la
              app (Firebase Auth usa el email). Solo modificarlo si es necesario
              y coordinar con el inversor.
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-t-muted mb-1">
              Nombre *
            </label>
            <Input
              type="text"
              required
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-t-muted mb-1">
              Estado
            </label>
            <Select
              value={form.status}
              onChange={(v) =>
                setForm({ ...form, status: v as "ACTIVE" | "INACTIVE" })
              }
              options={[
                { value: "ACTIVE", label: "Activo" },
                { value: "INACTIVE", label: "Inactivo" },
              ]}
            />
            <p className="mt-1 text-xs text-t-dim">
              Si está inactivo, pierde acceso a la app de clientes y queda
              excluido de cálculos globales.
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-t-muted mb-1">
              Frecuencia trading fee
            </label>
            <Select
              value={form.tradingFeeFrequency}
              onChange={(v) =>
                setForm({
                  ...form,
                  tradingFeeFrequency: v as
                    | "MONTHLY"
                    | "QUARTERLY"
                    | "SEMESTRAL"
                    | "ANNUAL",
                })
              }
              options={[
                { value: "MONTHLY", label: "Mensual" },
                { value: "QUARTERLY", label: "Trimestral" },
                { value: "SEMESTRAL", label: "Semestral" },
                { value: "ANNUAL", label: "Anual" },
              ]}
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
              value={form.tradingFeePercentage}
              onChange={(e) =>
                setForm({ ...form, tradingFeePercentage: e.target.value })
              }
            />
          </div>

          {investor?.hasPassword ? (
            <div>
              <label className="block text-sm font-medium text-t-muted mb-1">
                Nueva contraseña
                <span className="ml-2 text-xs text-info font-normal">
                  (tiene contraseña)
                </span>
              </label>
              <div className="relative">
                <Input
                  type={showNewPassword ? "text" : "password"}
                  value={form.newPassword}
                  onChange={(e) =>
                    setForm({ ...form, newPassword: e.target.value })
                  }
                  placeholder="Dejar vacío para no cambiar"
                  minLength={6}
                  className="pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowNewPassword((v) => !v)}
                  className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-t-dim hover:text-t-primary focus:outline-none focus:ring-2 focus:ring-primary"
                  title={showNewPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
                  aria-label={showNewPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
                >
                  {showNewPassword ? (
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
                Mínimo 6 caracteres. Solo se actualiza si completás este campo.
              </p>
            </div>
          ) : (
            <div className="rounded-lg bg-dark-section p-4 text-sm text-t-muted">
              <p className="font-medium text-t-muted">
                Método de autenticación: Google
              </p>
              <p className="mt-1">
                Este inversor ingresa con Google. No se puede configurar
                contraseña.
              </p>
            </div>
          )}

          <div className="flex gap-3 pt-2">
            <Button type="submit" disabled={submitting}>
              {submitting ? "Guardando..." : "Guardar cambios"}
            </Button>
            <Button
              type="button"
              onClick={() => navigate("/investors")}
              className="bg-dark-section hover:bg-primary-dim"
            >
              Cancelar
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};
