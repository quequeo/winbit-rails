import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

export const InvestorsPage = () => {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({ email: '', name: '', code: '' });
  const [submitting, setSubmitting] = useState(false);

  const fetchInvestors = () => {
    api
      .getAdminInvestors()
      .then((res) => {
        setData(res);
      })
      .catch((e) => {
        setError(e.message);
      });
  };

  useEffect(() => {
    fetchInvestors();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.createInvestor(formData);
      setFormData({ email: '', name: '', code: '' });
      setShowForm(false);
      fetchInvestors();
    } catch (err: any) {
      alert(err.message || 'Error al crear inversor');
    } finally {
      setSubmitting(false);
    }
  };

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  const investors = (data?.data || []) as any[];

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Inversores</h1>
        </div>
        <Button onClick={() => setShowForm(!showForm)} className="shrink-0">
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
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Código *</label>
              <Input
                type="text"
                required
                value={formData.code}
                onChange={(e) => setFormData({ ...formData, code: e.target.value })}
                placeholder="INV001"
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
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
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
                ${(inv.portfolio?.currentBalance ?? 0).toLocaleString('en-US')}
              </p>
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
                <th className="py-2">Nombre</th>
                <th className="py-2">Email</th>
                <th className="py-2">Balance</th>
                <th className="py-2">Estado</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {investors.map((inv: any) => (
                <tr key={inv.id} className="text-sm">
                  <td className="py-2 font-medium">{inv.name}</td>
                  <td className="py-2 text-gray-600">{inv.email}</td>
                  <td className="py-2">${(inv.portfolio?.currentBalance ?? 0).toLocaleString('en-US')}</td>
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
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
