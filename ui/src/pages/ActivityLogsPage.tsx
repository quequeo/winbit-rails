import { useEffect, useState } from 'react';
import { api } from '../lib/api';

type ActivityLog = {
  id: number;
  action: string;
  action_description: string;
  user: {
    id: string;
    name: string;
    email: string;
  };
  target: {
    type: string;
    id: string;
    display: string;
  };
  metadata: Record<string, any>;
  created_at: string;
};

type Pagination = {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
};

export const ActivityLogsPage = () => {
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [pagination, setPagination] = useState<Pagination | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [filterAction, setFilterAction] = useState('');

  const fetchLogs = async (page: number = 1) => {
    try {
      setLoading(true);
      setError(null);

      const params: any = { page, per_page: 50 };
      if (filterAction) params.filter_action = filterAction;

      const res = await api.getActivityLogs(params);
      setLogs(res?.data?.logs || []);
      setPagination(res?.data?.pagination || null);
      setCurrentPage(page);
    } catch (err: any) {
      console.error('❌ Error fetching activity logs:', err);
      setError(err?.message || 'Error al cargar actividad');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs(1);
  }, [filterAction]);

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('es-AR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };

  const getActionBadgeColor = (action: string) => {
    if (action.includes('approve')) return 'bg-green-100 text-green-800';
    if (action.includes('reject')) return 'bg-red-100 text-red-800';
    if (action.includes('delete') || action.includes('deactivate'))
      return 'bg-red-100 text-red-800';
    if (action.includes('create')) return 'bg-blue-100 text-blue-800';
    if (action.includes('update')) return 'bg-yellow-100 text-yellow-800';
    if (action.includes('activate')) return 'bg-green-100 text-green-800';
    return 'bg-gray-100 text-gray-800';
  };

  if (loading && logs.length === 0) {
    return (
      <div className="rounded-lg bg-white p-6 shadow-sm">
        <div className="text-gray-600">Cargando actividad...</div>
      </div>
    );
  }

  return (
    <div className="rounded-lg bg-white p-6 shadow-sm">
      {/* Header */}
      <div className="mb-6 border-b border-gray-200 pb-4">
        <h2 className="text-2xl font-semibold text-gray-900">Registro de Actividad</h2>
        <p className="mt-1 text-sm text-gray-600">
          Historial completo de acciones realizadas por los administradores
        </p>
      </div>

      {/* Filters */}
      <div className="mb-6 flex flex-wrap gap-4">
        <div className="flex-1 min-w-[200px]">
          <label htmlFor="filterAction" className="mb-1 block text-sm font-medium text-gray-700">
            Filtrar por acción
          </label>
          <select
            id="filterAction"
            value={filterAction}
            onChange={(e) => setFilterAction(e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#58b098] focus:outline-none focus:ring-1 focus:ring-[#58b098]"
          >
            <option value="">Todas las acciones</option>
            <option value="approve_request">Aprobar solicitud</option>
            <option value="reject_request">Rechazar solicitud</option>
            <option value="update_portfolio">Actualizar portfolio</option>
            <option value="create_investor">Crear inversor</option>
            <option value="update_investor">Actualizar inversor</option>
            <option value="deactivate_investor">Desactivar inversor</option>
            <option value="activate_investor">Activar inversor</option>
            <option value="delete_investor">Eliminar inversor</option>
            <option value="create_admin">Crear admin</option>
            <option value="update_admin">Actualizar admin</option>
            <option value="delete_admin">Eliminar admin</option>
            <option value="update_settings">Actualizar configuración</option>
          </select>
        </div>
      </div>

      {error && (
        <div className="mb-4 rounded-lg bg-red-50 p-4 text-sm text-red-800">{error}</div>
      )}

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                Fecha
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                Admin
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                Acción
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                Objetivo
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                Detalles
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 bg-white">
            {logs.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-sm text-gray-500">
                  No hay actividad registrada
                </td>
              </tr>
            ) : (
              logs.map((log) => (
                <tr key={log.id} className="hover:bg-gray-50">
                  <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-900">
                    {formatDate(log.created_at)}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <div className="font-medium text-gray-900">{log.user.name}</div>
                    <div className="text-gray-500">{log.user.email}</div>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <span
                      className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${getActionBadgeColor(log.action)}`}
                    >
                      {log.action_description}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <div className="font-medium text-gray-900">{log.target.display}</div>
                    <div className="text-xs text-gray-500">
                      {log.target.type} #{log.target.id}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {log.metadata && Object.keys(log.metadata).length > 0 ? (
                      <div className="max-w-xs">
                        {Object.entries(log.metadata).map(([key, value]) => {
                          // Traducir claves al español
                          const labelMap: Record<string, string> = {
                            nuevo_valor: 'Nuevo valor',
                            emails: 'Emails',
                            cantidad: 'Cantidad',
                            amount: 'Monto',
                            status: 'Estado',
                            from: 'Desde',
                            to: 'Hacia',
                            reason: 'Razón',
                            request_type: 'Tipo',
                            method: 'Método',
                            network: 'Red',
                          };
                          
                          const label = labelMap[key] || key;
                          
                          return (
                            <div key={key} className="text-xs mb-1">
                              <span className="font-medium text-gray-700">{label}:</span>{' '}
                              <span className="text-gray-600">
                                {typeof value === 'number' && key === 'amount'
                                  ? `$${value.toLocaleString('es-AR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
                                  : String(value)}
                              </span>
                            </div>
                          );
                        })}
                      </div>
                    ) : (
                      <span className="text-gray-400">—</span>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {pagination && pagination.total_pages > 1 && (
        <div className="mt-6 flex items-center justify-between border-t border-gray-200 pt-4">
          <div className="text-sm text-gray-700">
            Página {pagination.page} de {pagination.total_pages} ({pagination.total} registros)
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => fetchLogs(currentPage - 1)}
              disabled={currentPage === 1 || loading}
              className="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Anterior
            </button>
            <button
              onClick={() => fetchLogs(currentPage + 1)}
              disabled={currentPage === pagination.total_pages || loading}
              className="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Siguiente
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
