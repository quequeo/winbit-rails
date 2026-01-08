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
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState({ email: '', name: '', role: 'ADMIN' as 'ADMIN' | 'SUPERADMIN' });
  const [loggedInEmail, setLoggedInEmail] = useState<string>('');

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
    api.getAdminSession().then((res) => {
      setLoggedInEmail(res?.data?.email || '');
    }).catch(() => {});
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

  const handleEditSubmit = async (e: React.FormEvent, id: string) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.updateAdmin(id, editForm);
      setEditingId(null);
      fetchAdmins();
    } catch (err: any) {
      alert(err.message || 'Error al actualizar admin');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (admin: any) => {
    if (admin.email === loggedInEmail) {
      alert('No puedes eliminar tu propia cuenta.');
      return;
    }
    if (!confirm(`¿Estás seguro de eliminar a ${admin.email}?`)) return;
    try {
      await api.deleteAdmin(admin.id);
      fetchAdmins();
    } catch (err: any) {
      alert(err.message || 'Error al eliminar admin');
    }
  };

  const startEdit = (admin: any) => {
    setEditingId(admin.id);
    setEditForm({ email: admin.email, name: admin.name || '', role: admin.role });
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
              <label htmlFor="admin-role" className="block text-sm font-medium text-gray-700 mb-1">Rol *</label>
              <select
                id="admin-role"
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
            {editingId === a.id ? (
              <form onSubmit={(e) => handleEditSubmit(e, a.id)} className="space-y-3">
                <Input
                  type="email"
                  required
                  value={editForm.email}
                  onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                  placeholder="Email"
                  className="text-sm"
                />
                <Input
                  type="text"
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                  placeholder="Nombre"
                  className="text-sm"
                />
                <select
                  required
                  value={editForm.role}
                  onChange={(e) => setEditForm({ ...editForm, role: e.target.value as 'ADMIN' | 'SUPERADMIN' })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none"
                >
                  <option value="ADMIN">Admin</option>
                  <option value="SUPERADMIN">Super Admin</option>
                </select>
                <div className="flex gap-2">
                  <Button type="submit" disabled={submitting} className="text-sm py-1 px-3">
                    Guardar
                  </Button>
                  <Button
                    type="button"
                    onClick={() => setEditingId(null)}
                    className="text-sm py-1 px-3 bg-gray-500 hover:bg-gray-600"
                  >
                    Cancelar
                  </Button>
                </div>
              </form>
            ) : (
              <>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
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
                <div className="mt-3 flex gap-2">
                  <button
                    onClick={() => startEdit(a)}
                    className="p-2 text-blue-600 hover:bg-blue-50 rounded"
                    title="Editar"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                    </svg>
                  </button>
                  <button
                    onClick={() => handleDelete(a)}
                    disabled={a.email === loggedInEmail}
                    className={`p-2 rounded ${
                      a.email === loggedInEmail
                        ? 'text-gray-400 cursor-not-allowed'
                        : 'text-red-600 hover:bg-red-50'
                    }`}
                    title={a.email === loggedInEmail ? 'No puedes eliminar tu propia cuenta' : 'Eliminar'}
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              </>
            )}
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
                <th className="py-2 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {admins.map((a: any) => (
                <tr key={a.id} className="text-sm">
                  {editingId === a.id ? (
                    <>
                      <td className="py-2">
                        <Input
                          type="email"
                          required
                          value={editForm.email}
                          onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                          className="text-sm"
                        />
                      </td>
                      <td className="py-2">
                        <Input
                          type="text"
                          value={editForm.name}
                          onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                          className="text-sm"
                        />
                      </td>
                      <td className="py-2">
                        <select
                          required
                          value={editForm.role}
                          onChange={(e) => setEditForm({ ...editForm, role: e.target.value as 'ADMIN' | 'SUPERADMIN' })}
                          className="w-full rounded-lg border border-gray-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-none"
                        >
                          <option value="ADMIN">Admin</option>
                          <option value="SUPERADMIN">Super Admin</option>
                        </select>
                      </td>
                      <td className="py-2 text-right">
                        <div className="flex gap-2 justify-end">
                          <Button
                            onClick={(e) => handleEditSubmit(e, a.id)}
                            disabled={submitting}
                            className="text-sm py-1 px-3"
                          >
                            Guardar
                          </Button>
                          <Button
                            onClick={() => setEditingId(null)}
                            className="text-sm py-1 px-3 bg-gray-500 hover:bg-gray-600"
                          >
                            Cancelar
                          </Button>
                        </div>
                      </td>
                    </>
                  ) : (
                    <>
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
                      <td className="py-2 text-right">
                        <div className="flex gap-2 justify-end">
                          <button
                            onClick={() => startEdit(a)}
                            className="p-2 text-blue-600 hover:bg-blue-50 rounded"
                            title="Editar"
                          >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                            </svg>
                          </button>
                          <button
                            onClick={() => handleDelete(a)}
                            disabled={a.email === loggedInEmail}
                            className={`p-2 rounded ${
                              a.email === loggedInEmail
                                ? 'text-gray-400 cursor-not-allowed'
                                : 'text-red-600 hover:bg-red-50'
                            }`}
                            title={a.email === loggedInEmail ? 'No puedes eliminar tu propia cuenta' : 'Eliminar'}
                          >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        </div>
                      </td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
