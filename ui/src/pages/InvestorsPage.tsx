import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';
import { formatCurrencyAR } from '../lib/formatters';

const frequencyLabel = (freq: string) => {
  if (freq === 'MONTHLY') return 'Mensual';
  if (freq === 'ANNUAL') return 'Anual';
  if (freq === 'SEMESTRAL') return 'Semestral';
  return 'Trimestral';
};

export const InvestorsPage = () => {
  const navigate = useNavigate();
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({ email: '', name: '', tradingFeePercentage: '30', password: '' });
  const [submitting, setSubmitting] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState<{ isOpen: boolean; investor: any | null }>({
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
        alert('El porcentaje debe estar entre 0 y 100');
        return;
      }

      const { password, tradingFeePercentage, ...rest } = formData;
      const payload = {
        ...rest,
        trading_fee_percentage: Number(tradingFeePercentage),
      };

      await api.createInvestor(password ? { ...payload, password } : payload);
      setFormData({ email: '', name: '', tradingFeePercentage: '30', password: '' });
      setShowForm(false);
      fetchInvestors();
    } catch (err: any) {
      alert(err.message || 'Error al crear inversor');
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

  const handleToggleStatus = async (investor: any) => {
    try {
      await api.toggleInvestorStatus(investor.id);
      fetchInvestors();
    } catch (err: any) {
      alert(err.message || 'Error al cambiar status');
    }
  };

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  const investors = (data?.data || []) as any[];

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-2 md:gap-4">
        <h1 className="text-3xl font-bold text-gray-900">Inversores</h1>
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
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Trading fee (%)</label>
              <Input
                type="number"
                min={0}
                max={100}
                step="0.1"
                value={formData.tradingFeePercentage}
                onChange={(e) => setFormData({ ...formData, tradingFeePercentage: e.target.value })}
                placeholder="30"
              />
              <p className="mt-1 text-xs text-gray-500">Default 30%. Podés editarlo por inversor.</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Contraseña</label>
              <Input
                type="password"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                placeholder="Mínimo 6 caracteres"
                minLength={6}
              />
              <p className="mt-1 text-xs text-gray-500">Opcional. Si no se establece, el inversor solo podrá acceder con Google.</p>
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
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-gray-900">{inv.name}</p>
                <p className="truncate mt-1 text-sm text-gray-600">{inv.email}</p>
              </div>
              <button
                onClick={() => handleToggleStatus(inv)}
                className={`shrink-0 inline-flex rounded-full px-2 py-0.5 text-[11px] font-semibold cursor-pointer ${
                  inv.status === 'ACTIVE'
                    ? 'bg-green-50 text-green-700 hover:bg-green-100'
                    : 'bg-red-50 text-red-700 hover:bg-red-100'
                }`}
                title={inv.status === 'ACTIVE' ? 'Desactivar' : 'Activar'}
              >
                {inv.status === 'ACTIVE' ? 'Activo' : 'Inactivo'}
              </button>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-3 text-sm">
              <div>
                <p className="text-xs text-gray-500">Capital Actual</p>
                <p className="mt-1 font-mono font-semibold text-gray-900">
                  {formatCurrencyAR(inv.portfolio?.currentBalance ?? 0)}
                </p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Total Invertido</p>
                <p className="mt-1 font-mono font-semibold text-gray-900">
                  {formatCurrencyAR(inv.portfolio?.totalInvested ?? 0)}
                </p>
              </div>
            </div>
            <div className="mt-2 flex items-center justify-between text-xs text-gray-500">
              <span>Fee: {frequencyLabel(inv.tradingFeeFrequency)} ({inv.tradingFeePercentage ?? 30}%)</span>
              <span>{inv.hasPassword ? '🔑 Pass' : 'Google'}</span>
            </div>
            <div className="mt-3 flex gap-2">
              <button
                onClick={() => navigate(`/investors/${inv.id}/edit`)}
                className="rounded p-2 text-[#58b098] hover:bg-[#58b098]/10"
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
          </div>
        ))}
      </div>

      {/* Desktop/tablet: table */}
      <div className="hidden md:block rounded-lg bg-white p-6 shadow">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead>
              <tr className="text-left text-sm text-gray-500 border-b border-gray-200">
                <th className="pb-3 pr-4">Nombre</th>
                <th className="pb-3 pr-4">Email</th>
                <th className="pb-3 pr-4 text-center">Status</th>
                <th className="pb-3 pr-4 text-right">Capital Actual</th>
                <th className="pb-3 pr-4 text-center">Fee</th>
                <th className="pb-3 pr-4 text-center">Auth</th>
                <th className="pb-3 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {investors.map((inv: any) => (
                <tr key={inv.id} className={`text-sm ${inv.status === 'INACTIVE' ? 'opacity-50' : ''}`}>
                  <td className="py-3 pr-4 font-medium">{inv.name}</td>
                  <td className="py-3 pr-4 text-gray-600">{inv.email}</td>
                  <td className="py-3 pr-4 text-center">
                    <button
                      onClick={() => handleToggleStatus(inv)}
                      className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold cursor-pointer transition-colors ${
                        inv.status === 'ACTIVE'
                          ? 'bg-green-50 text-green-700 hover:bg-green-100'
                          : 'bg-red-50 text-red-700 hover:bg-red-100'
                      }`}
                      title={inv.status === 'ACTIVE' ? 'Click para desactivar' : 'Click para activar'}
                    >
                      {inv.status === 'ACTIVE' ? 'Activo' : 'Inactivo'}
                    </button>
                  </td>
                  <td className="py-3 pr-4 text-right font-mono text-gray-900">
                    {formatCurrencyAR(inv.portfolio?.currentBalance ?? 0)}
                  </td>
                  <td className="py-3 pr-4 text-center">
                    <span className="inline-flex rounded-full bg-purple-50 px-2 py-0.5 text-xs font-semibold text-purple-700">
                      {frequencyLabel(inv.tradingFeeFrequency)} ({inv.tradingFeePercentage ?? 30}%)
                    </span>
                  </td>
                  <td className="py-3 pr-4 text-center">
                    {inv.hasPassword ? (
                      <span className="inline-flex items-center gap-1 rounded-full bg-blue-50 px-2 py-0.5 text-xs font-semibold text-blue-700" title="Contraseña configurada">
                        🔑
                      </span>
                    ) : (
                      <span className="text-xs text-gray-400">Google</span>
                    )}
                  </td>
                  <td className="py-3 text-right">
                    <div className="flex gap-1 justify-end">
                      <button
                        onClick={() => navigate(`/investors/${inv.id}/edit`)}
                        className="rounded p-1.5 text-[#58b098] hover:bg-[#58b098]/10"
                        title="Editar"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                        </svg>
                      </button>
                      <button
                        onClick={() => handleDelete(inv)}
                        className="p-1.5 text-red-600 hover:bg-red-50 rounded"
                        title="Eliminar"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
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
