import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';

export const EditInvestorPage = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [investor, setInvestor] = useState<any>(null);
  const [form, setForm] = useState({
    email: '',
    name: '',
    status: 'ACTIVE' as 'ACTIVE' | 'INACTIVE',
    tradingFeeFrequency: 'QUARTERLY' as 'MONTHLY' | 'QUARTERLY' | 'SEMESTRAL' | 'ANNUAL',
    newPassword: '',
  });

  useEffect(() => {
    api
      .getAdminInvestors({})
      .then((res) => {
        const inv = (res?.data || []).find((i: any) => String(i.id) === id);
        if (inv) {
          setInvestor(inv);
          setForm({
            email: inv.email,
            name: inv.name,
            status: inv.status || 'ACTIVE',
            tradingFeeFrequency: inv.tradingFeeFrequency || 'QUARTERLY',
            newPassword: '',
          });
        } else {
          setError('Inversor no encontrado');
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
      const body: any = {
        email: form.email,
        name: form.name,
        status: form.status,
        trading_fee_frequency: form.tradingFeeFrequency,
      };
      if (form.newPassword) body.password = form.newPassword;
      await api.updateInvestor(id, body);
      navigate('/investors');
    } catch (err: any) {
      alert(err.message || 'Error al actualizar inversor');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <div className="text-gray-600">Cargando...</div>;
  if (error) return <div className="text-red-600">{error}</div>;

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div className="flex items-center gap-4">
        <button onClick={() => navigate('/investors')} className="text-gray-500 hover:text-gray-700">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-2xl font-bold text-gray-900">Editar Inversor</h1>
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
            <label className="block text-sm font-medium text-gray-700 mb-1">Nombre *</label>
            <Input
              type="text"
              required
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Estado</label>
            <Select
              value={form.status}
              onChange={(v) => setForm({ ...form, status: v as 'ACTIVE' | 'INACTIVE' })}
              options={[
                { value: 'ACTIVE', label: 'Activo' },
                { value: 'INACTIVE', label: 'Inactivo' },
              ]}
            />
            <p className="mt-1 text-xs text-gray-500">
              Si está inactivo, pierde acceso a la app de clientes y queda excluido de cálculos globales.
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Frecuencia trading fee</label>
            <Select
              value={form.tradingFeeFrequency}
              onChange={(v) => setForm({ ...form, tradingFeeFrequency: v as 'MONTHLY' | 'QUARTERLY' | 'SEMESTRAL' | 'ANNUAL' })}
              options={[
                { value: 'MONTHLY', label: 'Mensual' },
                { value: 'QUARTERLY', label: 'Trimestral' },
                { value: 'SEMESTRAL', label: 'Semestral' },
                { value: 'ANNUAL', label: 'Anual' },
              ]}
            />
          </div>

          {investor?.hasPassword ? (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Nueva contraseña
                <span className="ml-2 text-xs text-blue-600 font-normal">(tiene contraseña)</span>
              </label>
              <Input
                type="password"
                value={form.newPassword}
                onChange={(e) => setForm({ ...form, newPassword: e.target.value })}
                placeholder="Dejar vacío para no cambiar"
                minLength={6}
              />
              <p className="mt-1 text-xs text-gray-500">Mínimo 6 caracteres. Solo se actualiza si completás este campo.</p>
            </div>
          ) : (
            <div className="rounded-lg bg-gray-50 p-4 text-sm text-gray-600">
              <p className="font-medium text-gray-700">Método de autenticación: Google</p>
              <p className="mt-1">Este inversor ingresa con Google. No se puede configurar contraseña.</p>
            </div>
          )}

          <div className="flex gap-3 pt-2">
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Guardando...' : 'Guardar cambios'}
            </Button>
            <Button type="button" onClick={() => navigate('/investors')} className="bg-gray-500 hover:bg-gray-600">
              Cancelar
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};
