import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';
import { formatCurrencyAR } from '../lib/formatters';

export const InvestorsPage = () => {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({ email: '', name: '' });
  const [submitting, setSubmitting] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState({ email: '', name: '' });
  const [sortBy, setSortBy] = useState<string>('balance');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [deleteConfirm, setDeleteConfirm] = useState<{ isOpen: boolean; investor: any | null }>({
    isOpen: false,
    investor: null,
  });

  const fetchInvestors = () => {
    api
      .getAdminInvestors({ sort_by: sortBy, sort_order: sortOrder })
      .then((res) => {
        setData(res);
      })
      .catch((e) => {
        setError(e.message);
      });
  };

  useEffect(() => {
    fetchInvestors();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sortBy, sortOrder]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.createInvestor(formData);
      setFormData({ email: '', name: '' });
      setShowForm(false);
      fetchInvestors();
    } catch (err: any) {
      alert(err.message || 'Error al crear inversor');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEditSubmit = async (e: React.FormEvent, id: string) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.updateInvestor(id, editForm);
      setEditingId(null);
      fetchInvestors();
    } catch (err: any) {
      alert(err.message || 'Error al actualizar inversor');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = (investor: any) => {
    setDeleteConfirm({ isOpen: true, investor });
  };

  const confirmDelete = async () => {
    if (!deleteConfirm.investor) return;
    try {
      await api.deleteInvestor(deleteConfirm.investor.id);
      fetchInvestors();
    } catch (err: any) {
      alert(err.message || 'Error al eliminar inversor');
    }
  };

  const startEdit = (investor: any) => {
    setEditingId(investor.id);
    setEditForm({ email: investor.email, name: investor.name });
  };

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  const investors = (data?.data || []) as any[];

  const handleSort = (field: string) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('desc');
    }
  };

  const getSortIcon = (field: string) => {
    if (sortBy !== field) return '↕️';
    return sortOrder === 'asc' ? '↑' : '↓';
  };

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-2 md:gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Inversores</h1>
        </div>
        <Button onClick={() => setShowForm(!showForm)} className="shrink-0 text-xs md:text-sm px-2 py-1.5 md:px-4 md:py-2">
          {showForm ? 'Cancelar' : '+ Agregar Inversor'}
        </Button>
      </div>

      {showForm && (
        <div className="rounded-lg bg-white p-6 shadow">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Nuevo Inversor</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
              <Input
                type="email"
                required
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                placeholder="inversor@ejemplo.com"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Nombre *</label>
              <Input
                type="text"
                required
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="María González"
              />
            </div>
            <div className="flex gap-3">
              <Button type="submit" disabled={submitting}>
                {submitting ? 'Creando...' : 'Crear Inversor'}
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
        {investors.map((inv: any) => (
          <div key={inv.id} className="w-full overflow-hidden rounded-lg bg-white p-4 shadow">
            {editingId === inv.id ? (
              <form onSubmit={(e) => handleEditSubmit(e, inv.id)} className="space-y-3">
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
                  required
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                  placeholder="Nombre"
                  className="text-sm"
                />
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
                    <p className="truncate text-sm font-semibold text-gray-900">{inv.name}</p>
                    <p className="truncate mt-1 text-sm text-gray-600">{inv.email}</p>
                  </div>
                  <span
                    className={`shrink-0 inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                      inv.status === 'ACTIVE' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                    }`}
                  >
                    {inv.status === 'ACTIVE' ? 'Activo' : 'Inactivo'}
                  </span>
                </div>

                <div className="mt-4">
                  <p className="text-xs text-gray-500">Balance</p>
                  <p className="mt-1 font-mono font-semibold text-gray-900">
                    {formatCurrencyAR(inv.portfolio?.currentBalance ?? 0)}
                  </p>
                </div>

                <div className="mt-3 flex gap-2">
                  <button
                    onClick={() => startEdit(inv)}
                    className="p-2 text-blue-600 hover:bg-blue-50 rounded"
                    title="Editar"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                    </svg>
                  </button>
                  <button
                    onClick={() => handleDelete(inv)}
                    className="p-2 text-red-600 hover:bg-red-50 rounded"
                    title="Eliminar"
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
                <th className="py-2">
                  <button
                    onClick={() => handleSort('name')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Nombre
                    <span className="text-xs">{getSortIcon('name')}</span>
                  </button>
                </th>
                <th className="py-2">Email</th>
                <th className="py-2">
                  <button
                    onClick={() => handleSort('balance')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Balance
                    <span className="text-xs">{getSortIcon('balance')}</span>
                  </button>
                </th>
                <th className="py-2">
                  <button
                    onClick={() => handleSort('status')}
                    className="flex items-center gap-1 hover:text-gray-700"
                  >
                    Estado
                    <span className="text-xs">{getSortIcon('status')}</span>
                  </button>
                </th>
                <th className="py-2 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {investors.map((inv: any) => (
                <tr key={inv.id} className="text-sm">
                  {editingId === inv.id ? (
                    <>
                      <td className="py-2">
                        <Input
                          type="text"
                          required
                          value={editForm.name}
                          onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                          className="text-sm"
                        />
                      </td>
                      <td className="py-2">
                        <Input
                          type="email"
                          required
                          value={editForm.email}
                          onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                          className="text-sm"
                        />
                      </td>
                      <td className="py-2" colSpan={2}></td>
                      <td className="py-2 text-right">
                        <div className="flex gap-2 justify-end">
                          <Button
                            onClick={(e) => handleEditSubmit(e, inv.id)}
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
                      <td className="py-2 font-medium">{inv.name}</td>
                      <td className="py-2 text-gray-600">{inv.email}</td>
                      <td className="py-2">{formatCurrencyAR(inv.portfolio?.currentBalance ?? 0)}</td>
                      <td className="py-2">
                        <span
                          className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                            inv.status === 'ACTIVE'
                              ? 'bg-green-100 text-green-800'
                              : 'bg-gray-100 text-gray-800'
                          }`}
                        >
                          {inv.status === 'ACTIVE' ? 'Activo' : 'Inactivo'}
                        </span>
                      </td>
                      <td className="py-2 text-right">
                        <div className="flex gap-2 justify-end">
                          <button
                            onClick={() => startEdit(inv)}
                            className="p-2 text-blue-600 hover:bg-blue-50 rounded"
                            title="Editar"
                          >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                            </svg>
                          </button>
                          <button
                            onClick={() => handleDelete(inv)}
                            className="p-2 text-red-600 hover:bg-red-50 rounded"
                            title="Eliminar"
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

      <ConfirmDialog
        isOpen={deleteConfirm.isOpen}
        onClose={() => setDeleteConfirm({ isOpen: false, investor: null })}
        onConfirm={confirmDelete}
        title="Eliminar Inversor"
        message={
          deleteConfirm.investor ? (
            <>
              ¿Estás seguro de eliminar a{' '}
              <span className="font-semibold">{deleteConfirm.investor.name}</span>?
              <br />
              <span className="text-red-600">Esta acción no se puede deshacer.</span>
            </>
          ) : (
            ''
          )
        }
        confirmText="Eliminar"
        cancelText="Cancelar"
        confirmVariant="danger"
      />
    </div>
  );
};
