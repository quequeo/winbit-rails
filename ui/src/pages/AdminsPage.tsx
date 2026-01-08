import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

export const AdminsPage = () => {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({ email: '', name: '', role: 'ADMIN' as 'ADMIN' | 'SUPERADMIN' });
  const [submitting, setSubmitting] = useState(false);

  const fetchAdmins = () => {
    api
      .getAdminAdmins()
      .then((res) => {
        setData(res);
      })
      .catch((e) => {
        setError(e.message);
      });
  };

  useEffect(() => {
    fetchAdmins();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.createAdmin(formData);
      setFormData({ email: '', name: '', role: 'ADMIN' });
      setShowForm(false);
      fetchAdmins();
    } catch (err: any) {
      alert(err.message || 'Error al crear admin');
    } finally {
      setSubmitting(false);
    }
  };

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  const admins = (data?.data || []) as any[];

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Admins</h1>
          <p className="text-gray-600 mt-1">Gestiona los usuarios que pueden acceder al panel.</p>
        </div>
        <Button onClick={() => setShowForm(!showForm)} className="shrink-0">
          {showForm ? 'Cancelar' : '+ Agregar Admin'}
        </Button>
      </div>

      {showForm && (
        <div className="rounded-lg bg-white p-6 shadow">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Nuevo Admin</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
              <Input
                type="email"
                required
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                placeholder="admin@ejemplo.com"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Nombre (opcional)</label>
              <Input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="Juan Pérez"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Rol *</label>
              <select
                required
                value={formData.role}
                onChange={(e) => setFormData({ ...formData, role: e.target.value as 'ADMIN' | 'SUPERADMIN' })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
              >
                <option value="ADMIN">Admin</option>
                <option value="SUPERADMIN">Super Admin</option>
              </select>
            </div>
            <div className="flex gap-3">
              <Button type="submit" disabled={submitting}>
                {submitting ? 'Creando...' : 'Crear Admin'}
              </Button>
              <Button type="button" onClick={() => setShowForm(false)} className="bg-gray-500 hover:bg-gray-600">
                Cancelar
              </Button>
            </div>
          </form>
        </div>
      )}

      {/* Mobile: cards */}
      <div className="grid gap-3 px-1 md:hidden">
        {admins.map((a: any) => (
          <div key={a.id} className="w-full overflow-hidden rounded-lg bg-white p-4 shadow">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-gray-900">{a.email}</p>
                <p className="mt-1 text-sm text-gray-600">{a.name || '-'}</p>
              </div>
              <span
                className={`shrink-0 inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                  a.role === 'SUPERADMIN' ? 'bg-purple-100 text-purple-800' : 'bg-blue-100 text-blue-800'
                }`}
              >
                {a.role === 'SUPERADMIN' ? 'Super Admin' : 'Admin'}
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Desktop/tablet: table */}
      <div className="hidden md:block rounded-lg bg-white p-6 shadow">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead>
              <tr className="text-left text-sm text-gray-500">
                <th className="py-2">Email</th>
                <th className="py-2">Nombre</th>
                <th className="py-2">Rol</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {admins.map((a: any) => (
                <tr key={a.id} className="text-sm">
                  <td className="py-2 font-medium">{a.email}</td>
                  <td className="py-2">{a.name || '-'}</td>
                  <td className="py-2">
                    <span
                      className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                        a.role === 'SUPERADMIN'
                          ? 'bg-purple-100 text-purple-800'
                          : 'bg-blue-100 text-blue-800'
                      }`}
                    >
                      {a.role === 'SUPERADMIN' ? 'Super Admin' : 'Admin'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
