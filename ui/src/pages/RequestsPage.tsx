import { useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { formatCurrencyAR } from '../lib/formatters';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

export const RequestsPage = () => {
  const [status, setStatus] = useState('');
  const [type, setType] = useState('');
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    investor_id: '',
    request_type: 'DEPOSIT',
    method: 'USDT',
    amount: '',
    network: '',
    status: 'PENDING',
  });
  const [submitting, setSubmitting] = useState(false);
  const [investors, setInvestors] = useState<any[]>([]);

  const params = useMemo(() => ({ status: status || undefined, type: type || undefined }), [status, type]);

  const load = () => {
    setError(null);
    api
      .getAdminRequests(params)
      .then((res) => setData(res))
      .catch((e) => setError(e.message));
  };

  useEffect(() => {
    load();
    api.getAdminInvestors().then((res) => setInvestors(res?.data || [])).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, type]);

  const approve = async (id: string) => {
    try {
      setBusyId(id);
      await api.approveRequest(id);
      load();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const reject = async (id: string) => {
    try {
      setBusyId(id);
      await api.rejectRequest(id);
      load();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.createRequest({ ...formData, amount: Number(formData.amount) });
      setFormData({ investor_id: '', request_type: 'DEPOSIT', method: 'USDT', amount: '', network: '', status: 'PENDING' });
      setShowForm(false);
      load();
    } catch (err: any) {
      alert(err.message || 'Error al guardar solicitud');
    } finally {
      setSubmitting(false);
    }
  };

  const cancelForm = () => {
    setShowForm(false);
    setFormData({ investor_id: '', request_type: 'DEPOSIT', method: 'USDT', amount: '', network: '', status: 'PENDING' });
  };

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  const requests = data.data.requests;
  const pendingCount = data.data.pendingCount;

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-2 md:gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Solicitudes</h1>
          <p className="mt-1 text-sm text-gray-600">
            {pendingCount} solicitud{pendingCount !== 1 ? 'es' : ''} pendiente
            {pendingCount !== 1 ? 's' : ''}
          </p>
        </div>
        <Button onClick={() => setShowForm(!showForm)} className="shrink-0 text-xs md:text-sm px-2 py-1.5 md:px-4 md:py-2">
          {showForm ? 'Cancelar' : '+ Agregar Solicitud'}
        </Button>
      </div>

      {showForm && (
        <div className="rounded-lg bg-white p-6 shadow">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Nueva Solicitud
          </h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label htmlFor="request-investor" className="block text-sm font-medium text-gray-700 mb-1">Inversor *</label>
                <select
                  id="request-investor"
                  required
                  value={formData.investor_id}
                  onChange={(e) => setFormData({ ...formData, investor_id: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
                >
                  <option value="">Seleccionar inversor</option>
                  {investors.map((inv: any) => (
                    <option key={inv.id} value={inv.id}>
                      {inv.name} ({inv.email})
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label htmlFor="request-type" className="block text-sm font-medium text-gray-700 mb-1">Tipo *</label>
                <select
                  id="request-type"
                  required
                  value={formData.request_type}
                  onChange={(e) => setFormData({ ...formData, request_type: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
                >
                  <option value="DEPOSIT">Depósito</option>
                  <option value="WITHDRAWAL">Retiro</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Método *</label>
                <select
                  required
                  value={formData.method}
                  onChange={(e) => setFormData({ ...formData, method: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
                >
                  <option value="USDT">USDT</option>
                  <option value="USDC">USDC</option>
                  <option value="LEMON_CASH">Lemon Cash</option>
                  <option value="CASH">Efectivo</option>
                  <option value="SWIFT">SWIFT</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Monto *</label>
                <Input
                  type="number"
                  required
                  min="0"
                  step="0.01"
                  value={formData.amount}
                  onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
                  placeholder="1000"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Red (opcional)</label>
                <select
                  value={formData.network}
                  onChange={(e) => setFormData({ ...formData, network: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
                >
                  <option value="">Sin red</option>
                  <option value="TRC20">TRC20</option>
                  <option value="BEP20">BEP20</option>
                  <option value="ERC20">ERC20</option>
                  <option value="POLYGON">POLYGON</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Estado *</label>
                <select
                  required
                  value={formData.status}
                  onChange={(e) => setFormData({ ...formData, status: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
                >
                  <option value="PENDING">Pendiente</option>
                  <option value="APPROVED">Aprobado</option>
                  <option value="REJECTED">Rechazado</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <Button type="submit" disabled={submitting}>
                {submitting ? 'Guardando...' : 'Crear Solicitud'}
              </Button>
              <Button type="button" onClick={cancelForm} className="bg-gray-500 hover:bg-gray-600">
                Cancelar
              </Button>
            </div>
          </form>
        </div>
      )}

      <div className="rounded-lg bg-white p-6 shadow">
        <div className="flex gap-4">
          <div>
            <label htmlFor="filter-type" className="mb-2 block text-sm font-medium text-gray-700">Tipo</label>
            <select
              id="filter-type"
              className="rounded-md border border-gray-300 px-3 py-2"
              value={type}
              onChange={(e) => setType(e.target.value)}
            >
              <option value="">Todos</option>
              <option value="DEPOSIT">Depósitos</option>
              <option value="WITHDRAWAL">Retiros</option>
            </select>
          </div>
          <div>
            <label htmlFor="filter-status" className="mb-2 block text-sm font-medium text-gray-700">Estado</label>
            <select
              id="filter-status"
              className="rounded-md border border-gray-300 px-3 py-2"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
            >
              <option value="">Todos</option>
              <option value="PENDING">Pendientes</option>
              <option value="APPROVED">Aprobados</option>
              <option value="REJECTED">Rechazados</option>
            </select>
          </div>
        </div>
      </div>

      {/* Mobile: cards */}
      <div className="grid gap-3 px-1 md:hidden">
        {requests.map((r: any) => (
          <div key={r.id} className="w-full overflow-hidden rounded-lg bg-white p-4 shadow">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-gray-900">{r.investor.name}</p>
                <p className="mt-1 text-xs text-gray-500">
                  {new Date(r.requestedAt).toLocaleDateString('es-AR', {
                    day: '2-digit',
                    month: '2-digit',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </p>
              </div>
              <span
                className={`shrink-0 inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                  r.status === 'PENDING'
                    ? 'bg-yellow-100 text-yellow-800'
                    : r.status === 'APPROVED'
                      ? 'bg-green-100 text-green-800'
                      : 'bg-red-100 text-red-800'
                }`}
              >
                {r.status === 'PENDING' ? 'Pendiente' : r.status === 'APPROVED' ? 'Aprobado' : 'Rechazado'}
              </span>
            </div>

            <div className="mt-3 flex flex-wrap items-center gap-2">
              <span
                className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                  r.type === 'DEPOSIT' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'
                }`}
              >
                {r.type === 'DEPOSIT' ? 'Depósito' : 'Retiro'}
              </span>
              <span className="text-xs text-gray-600">{r.method}</span>
              <span className="ml-auto font-mono text-sm font-semibold text-gray-900">
                {formatCurrencyAR(Number(r.amount))}
              </span>
            </div>

            {r.attachmentUrl && (
              <div className="mt-3">
                <a
                  href={r.attachmentUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                  </svg>
                  Ver comprobante
                </a>
              </div>
            )}

            {r.status === 'PENDING' && (
              <div className="mt-4 flex gap-2">
                <Button size="sm" onClick={() => approve(r.id)} disabled={busyId === r.id} className="flex-1">
                  Aprobar
                </Button>
                <Button
                  size="sm"
                  variant="destructive"
                  onClick={() => reject(r.id)}
                  disabled={busyId === r.id}
                  className="flex-1"
                >
                  Rechazar
                </Button>
              </div>
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
                <th className="py-2">Fecha</th>
                <th className="py-2">Inversor</th>
                <th className="py-2">Tipo</th>
                <th className="py-2">Método</th>
                <th className="py-2">Monto</th>
                <th className="py-2">Adjunto</th>
                <th className="py-2">Estado</th>
                <th className="py-2 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {requests.map((r: any) => (
                <tr key={r.id} className="text-sm">
                  <td className="py-2">
                    {new Date(r.requestedAt).toLocaleDateString('es-AR', {
                      day: '2-digit',
                      month: '2-digit',
                      year: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </td>
                  <td className="py-2">
                    <p className="font-medium">{r.investor.name}</p>
                  </td>
                  <td className="py-2">
                    <span
                      className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                        r.type === 'DEPOSIT' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'
                      }`}
                    >
                      {r.type === 'DEPOSIT' ? 'Depósito' : 'Retiro'}
                    </span>
                  </td>
                  <td className="py-2">{r.method}</td>
                  <td className="py-2 font-mono font-semibold">{formatCurrencyAR(Number(r.amount))}</td>
                  <td className="py-2">
                    {r.attachmentUrl ? (
                      <a
                        href={r.attachmentUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 text-blue-600 hover:text-blue-800"
                        title="Ver comprobante"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      </a>
                    ) : (
                      <span className="text-gray-400 text-sm">-</span>
                    )}
                  </td>
                  <td className="py-2">
                    <span
                      className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                        r.status === 'PENDING'
                          ? 'bg-yellow-100 text-yellow-800'
                          : r.status === 'APPROVED'
                            ? 'bg-green-100 text-green-800'
                            : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {r.status === 'PENDING'
                        ? 'Pendiente'
                        : r.status === 'APPROVED'
                          ? 'Aprobado'
                          : 'Rechazado'}
                    </span>
                  </td>
                  <td className="py-2 text-right">
                    {r.status === 'PENDING' && (
                      <div className="flex justify-end gap-2">
                        <Button size="sm" onClick={() => approve(r.id)} disabled={busyId === r.id}>
                          Aprobar
                        </Button>
                        <Button
                          size="sm"
                          variant="destructive"
                          onClick={() => reject(r.id)}
                          disabled={busyId === r.id}
                        >
                          Rechazar
                        </Button>
                      </div>
                    )}
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
