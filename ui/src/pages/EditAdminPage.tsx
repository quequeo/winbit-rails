import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

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
      <span className="h-4 w-4 rounded border border-gray-300 bg-white peer-checked:border-[#58b098] peer-checked:bg-[#58b098] peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-[#58b098]/40" />
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
    email: '',
    name: '',
    role: 'ADMIN' as 'ADMIN' | 'SUPERADMIN',
    notify_deposit_created: true,
    notify_withdrawal_created: true,
  });

  useEffect(() => {
    api
      .getAdminAdmins()
      .then((res) => {
        const adm = (res?.data || []).find((a: any) => String(a.id) === id);
        if (!adm) {
          setError('Admin no encontrado');
          return;
        }
        setForm({
          email: adm.email || '',
          name: adm.name || '',
          role: (adm.role || 'ADMIN') as 'ADMIN' | 'SUPERADMIN',
          notify_deposit_created: adm.notify_deposit_created ?? true,
          notify_withdrawal_created: adm.notify_withdrawal_created ?? true,
        });
      })
      .catch((e) => setError(e.message || 'Error al cargar admin'))
      .finally(() => setLoading(false));
  }, [id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!id) return;
    setSubmitting(true);
    try {
      await api.updateAdmin(id, form);
      navigate('/admins');
    } catch (err: any) {
      alert(err.message || 'Error al actualizar admin');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <div className="text-gray-600">Cargando...</div>;
  if (error) return <div className="text-red-600">{error}</div>;

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div className="flex items-center gap-4">
        <button onClick={() => navigate('/admins')} className="text-gray-500 hover:text-gray-700">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-2xl font-bold text-gray-900">Editar Admin</h1>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
            <Input
              type="email"
              required
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Nombre</label>
            <Input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </div>

          <div>
            <label htmlFor="admin-edit-role" className="block text-sm font-medium text-gray-700 mb-1">
              Rol *
            </label>
            <select
              id="admin-edit-role"
              required
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value as 'ADMIN' | 'SUPERADMIN' })}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
            >
              <option value="ADMIN">Admin</option>
              <option value="SUPERADMIN">Super Admin</option>
            </select>
          </div>

          <div className="rounded-lg border border-gray-200 p-4">
            <p className="text-sm font-semibold text-gray-900">Notificaciones</p>
            <p className="mt-1 text-xs text-gray-500">Actualmente hay 2 tipos configurables por admin.</p>
            <div className="mt-3 space-y-2">
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <WinbitCheckbox
                  checked={form.notify_deposit_created}
                  onChange={(next) => setForm({ ...form, notify_deposit_created: next })}
                />
                <span className="text-gray-700">Nueva solicitud de depósito</span>
              </label>
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <WinbitCheckbox
                  checked={form.notify_withdrawal_created}
                  onChange={(next) => setForm({ ...form, notify_withdrawal_created: next })}
                />
                <span className="text-gray-700">Nueva solicitud de retiro</span>
              </label>
            </div>
          </div>

          <div className="flex gap-3 pt-2">
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Guardando...' : 'Guardar cambios'}
            </Button>
            <Button type="button" onClick={() => navigate('/admins')} className="bg-gray-500 hover:bg-gray-600">
              Cancelar
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};
