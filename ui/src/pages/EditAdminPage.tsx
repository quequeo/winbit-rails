import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "../lib/api";
import type { ApiAdmin } from "../types";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";

const WinbitCheckbox = ({
  checked,
  onChange,
}: {
  checked: boolean;
  onChange: (next: boolean) => void;
}) => {
  return (
    <span className="relative inline-flex h-4 w-4 items-center justify-center">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="peer sr-only"
      />
      <span className="h-4 w-4 rounded border border-b-default bg-dark-card peer-checked:border-primary peer-checked:bg-primary peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-primary/40" />
      <svg
        aria-hidden
        viewBox="0 0 20 20"
        className="pointer-events-none absolute h-3 w-3 text-white opacity-0 peer-checked:opacity-100"
        fill="currentColor"
      >
        <path
          fillRule="evenodd"
          d="M16.704 5.29a1 1 0 010 1.414l-7.5 7.5a1 1 0 01-1.414 0l-3.5-3.5a1 1 0 011.414-1.414l2.793 2.793 6.793-6.793a1 1 0 011.414 0z"
          clipRule="evenodd"
        />
      </svg>
    </span>
  );
};

export const EditAdminPage = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    email: "",
    name: "",
    role: "ADMIN" as "ADMIN" | "SUPERADMIN",
    notify_deposit_created: true,
    notify_withdrawal_created: true,
  });

  useEffect(() => {
    api
      .getAdminAdmins()
      .then((res) => {
        const adm = (res?.data as ApiAdmin[] | undefined)?.find(
          (a) => String(a.id) === id,
        );
        if (!adm) {
          setError("Admin no encontrado");
          return;
        }
        setForm({
          email: adm.email || "",
          name: adm.name || "",
          role: (adm.role || "ADMIN") as "ADMIN" | "SUPERADMIN",
          notify_deposit_created: adm.notify_deposit_created ?? true,
          notify_withdrawal_created: adm.notify_withdrawal_created ?? true,
        });
      })
      .catch((e) => setError(e.message || "Error al cargar admin"))
      .finally(() => setLoading(false));
  }, [id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!id) return;
    setSubmitting(true);
    try {
      await api.updateAdmin(id, form);
      navigate("/admins");
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : "Error al actualizar admin");
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
          onClick={() => navigate("/admins")}
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
        <h1 className="text-2xl font-bold text-t-primary">Editar Admin</h1>
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
          </div>

          <div>
            <label className="block text-sm font-medium text-t-muted mb-1">
              Nombre
            </label>
            <Input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </div>

          <div>
            <label
              htmlFor="admin-edit-role"
              className="block text-sm font-medium text-t-muted mb-1"
            >
              Rol *
            </label>
            <select
              id="admin-edit-role"
              required
              value={form.role}
              onChange={(e) =>
                setForm({
                  ...form,
                  role: e.target.value as "ADMIN" | "SUPERADMIN",
                })
              }
              className="w-full rounded-lg border border-b-default px-3 py-2 focus:border-primary focus:outline-none"
            >
              <option value="ADMIN">Admin</option>
              <option value="SUPERADMIN">Super Admin</option>
            </select>
          </div>

          <div className="rounded-lg border border-b-default p-4">
            <p className="text-sm font-semibold text-t-primary">
              Notificaciones
            </p>
            <p className="mt-1 text-xs text-t-dim">
              Actualmente hay 2 tipos configurables por admin.
            </p>
            <div className="mt-3 space-y-2">
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <WinbitCheckbox
                  checked={form.notify_deposit_created}
                  onChange={(next) =>
                    setForm({ ...form, notify_deposit_created: next })
                  }
                />
                <span className="text-t-muted">
                  Nueva solicitud de depósito
                </span>
              </label>
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <WinbitCheckbox
                  checked={form.notify_withdrawal_created}
                  onChange={(next) =>
                    setForm({ ...form, notify_withdrawal_created: next })
                  }
                />
                <span className="text-t-muted">Nueva solicitud de retiro</span>
              </label>
            </div>
          </div>

          <div className="flex gap-3 pt-2">
            <Button type="submit" disabled={submitting}>
              {submitting ? "Guardando..." : "Guardar cambios"}
            </Button>
            <Button
              type="button"
              onClick={() => navigate("/admins")}
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
