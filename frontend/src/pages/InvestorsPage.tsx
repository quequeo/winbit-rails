import { useEffect, useState } from 'react';
import { api } from '../lib/api';

export const InvestorsPage = () => {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    api
      .getAdminInvestors()
      .then((res) => {
        if (isMounted) setData(res);
      })
      .catch((e) => {
        if (isMounted) setError(e.message);
      });
    return () => {
      isMounted = false;
    };
  }, []);

  if (error) return <div className="text-red-600">{error}</div>;
  if (!data) return <div className="text-gray-600">Cargando...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">Inversores</h1>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
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
              {data.data.map((inv: any) => (
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
