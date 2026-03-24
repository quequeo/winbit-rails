import { useEffect, useState } from "react";
import { api } from "../lib/api";

export const SettingsPage = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [notificationsEnabled, setNotificationsEnabled] = useState(false);
  const [whitelist, setWhitelist] = useState<string[]>([]);
  const [whitelistInput, setWhitelistInput] = useState("");

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.getAdminSettings();
      const data = res?.data || {};
      setNotificationsEnabled(data.investor_notifications_enabled || false);
      setWhitelist(data.investor_email_whitelist || []);
      setWhitelistInput((data.investor_email_whitelist || []).join(", "));
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Error al cargar configuración",
      );
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setError(null);
      setSuccess(null);

      // Parse whitelist
      const emails = whitelistInput
        .split(",")
        .map((e) => e.trim())
        .filter((e) => e.length > 0);

      await api.updateAdminSettings({
        investor_notifications_enabled: notificationsEnabled,
        investor_email_whitelist: emails,
      });

      setSuccess("Configuración guardada exitosamente");
      setWhitelist(emails);

      // Clear success message after 3 seconds
      setTimeout(() => setSuccess(null), 3000);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Error al guardar configuración",
      );
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="admin-card p-6">
        <div className="text-t-muted">Cargando configuración...</div>
      </div>
    );
  }

  return (
    <div className="admin-card p-6">
      <div className="mb-6 border-b border-b-default pb-4">
        <h2 className="text-2xl font-semibold text-t-primary">Configuración</h2>
        <p className="mt-1 text-sm text-t-muted">
          Gestiona las notificaciones y configuraciones de la aplicación
        </p>
      </div>

      {error && (
        <div className="mb-4 rounded-lg bg-error/15 p-4 text-sm text-error">
          {error}
        </div>
      )}

      {success && (
        <div className="mb-4 rounded-lg bg-success/15 p-4 text-sm text-success">
          {success}
        </div>
      )}

      <div className="space-y-6">
        {/* Notificaciones a Inversores */}
        <div className="rounded-lg border border-b-default p-4">
          <div className="mb-4">
            <h3 className="text-lg font-medium text-t-primary">
              Notificaciones a Inversores
            </h3>
            <p className="mt-1 text-sm text-t-muted">
              Controla si se envían emails automáticos a los inversores cuando
              se crean, aprueban o rechazan solicitudes.
            </p>
          </div>

          <div className="flex items-center">
            <input
              type="checkbox"
              id="notificationsEnabled"
              checked={notificationsEnabled}
              onChange={(e) => setNotificationsEnabled(e.target.checked)}
              className="h-4 w-4 rounded border-b-default text-primary focus:ring-primary"
            />
            <label
              htmlFor="notificationsEnabled"
              className="ml-3 text-sm font-medium text-t-primary"
            >
              Habilitar notificaciones por email a inversores
            </label>
          </div>

          {!notificationsEnabled && (
            <div className="mt-3 rounded-md bg-warning/15 p-3 text-sm text-warning">
              ⚠️ <strong>Notificaciones deshabilitadas:</strong> Los inversores
              no recibirán emails automáticos, excepto aquellos en la lista de
              testing.
            </div>
          )}

          {notificationsEnabled && (
            <div className="mt-3 rounded-md bg-success/15 p-3 text-sm text-success">
              ✅ <strong>Notificaciones habilitadas:</strong> Todos los
              inversores recibirán emails automáticos.
            </div>
          )}
        </div>

        {/* Whitelist para Testing */}
        <div className="rounded-lg border border-b-default p-4">
          <div className="mb-4">
            <h3 className="text-lg font-medium text-t-primary">
              Lista de Testing (Whitelist)
            </h3>
            <p className="mt-1 text-sm text-t-muted">
              Emails de inversores que <strong>siempre</strong> recibirán
              notificaciones, incluso si las notificaciones están
              deshabilitadas. Útil para testing antes del lanzamiento.
            </p>
          </div>

          <div>
            <label
              htmlFor="whitelist"
              className="mb-2 block text-sm font-medium text-t-primary"
            >
              Emails separados por comas
            </label>
            <textarea
              id="whitelist"
              rows={3}
              value={whitelistInput}
              onChange={(e) => setWhitelistInput(e.target.value)}
              placeholder="ejemplo@gmail.com, otro@gmail.com"
              className="w-full rounded-lg border border-b-default px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            />
            <p className="mt-1 text-xs text-t-dim">
              Los emails serán normalizados automáticamente (minúsculas, sin
              espacios).
            </p>
          </div>

          {whitelist.length > 0 && (
            <div className="mt-3">
              <p className="mb-2 text-sm font-medium text-t-muted">
                Emails en la whitelist actual:
              </p>
              <div className="flex flex-wrap gap-2">
                {whitelist.map((email) => (
                  <span
                    key={email}
                    className="inline-flex items-center rounded-full bg-primary-dim px-3 py-1 text-xs font-medium text-primary"
                  >
                    {email}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Botón Guardar */}
        <div className="flex justify-end border-t border-b-default pt-4">
          <button
            type="button"
            onClick={handleSave}
            disabled={saving}
            className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/80 disabled:opacity-50"
          >
            {saving ? "Guardando..." : "Guardar Configuración"}
          </button>
        </div>
      </div>
    </div>
  );
};
