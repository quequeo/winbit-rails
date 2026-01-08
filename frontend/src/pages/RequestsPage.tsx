import { useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';

export const RequestsPage = () => {
  const [status, setStatus] = useState('');
  const [type, setType] = useState('');
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

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

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  const requests = data.data.requests;
  const pendingCount = data.data.pendingCount;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Solicitudes</h1>
          <p className="mt-1 text-sm text-gray-600">
            {pendingCount} solicitud{pendingCount !== 1 ? 'es' : ''} pendiente
            {pendingCount !== 1 ? 's' : ''}
          </p>
        </div>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
        <div className="flex gap-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700">Tipo</label>
            <select
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
            <label className="mb-2 block text-sm font-medium text-gray-700">Estado</label>
            <select
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

      <div className="rounded-lg bg-white p-6 shadow">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead>
              <tr className="text-left text-sm text-gray-500">
                <th className="py-2">Fecha</th>
                <th className="py-2">Inversor</th>
                <th className="py-2">Tipo</th>
                <th className="py-2">Método</th>
                <th className="py-2">Monto</th>
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
                    <div>
                      <p className="font-medium">{r.investor.name}</p>
                      <p className="text-sm text-gray-500">{r.investor.code}</p>
                    </div>
                  </td>
                  <td className="py-2">
                    <span
                      className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                        r.type === 'DEPOSIT'
                          ? 'bg-blue-100 text-blue-800'
                          : 'bg-purple-100 text-purple-800'
                      }`}
                    >
                      {r.type === 'DEPOSIT' ? 'Depósito' : 'Retiro'}
                    </span>
                  </td>
                  <td className="py-2">{r.method}</td>
                  <td className="py-2 font-mono font-semibold">${Number(r.amount).toLocaleString('en-US')}</td>
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
                    {r.status === 'PENDING' ? (
                      <div className="flex justify-end gap-2">
                        <Button
                          size="sm"
                          onClick={() => approve(r.id)}
                          disabled={busyId === r.id}
                        >
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
                    ) : (
                      <span className="text-sm text-gray-500">
                        {r.processedAt ? new Date(r.processedAt).toLocaleDateString('es-AR') : '-'}
                      </span>
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
