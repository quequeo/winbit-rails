import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { formatCurrencyAR } from '../lib/formatters';

type DashboardData = {
  data: {
    investorCount: number;
    pendingRequestCount: number;
    totalAum: number;
  };
};

export const DashboardPage = () => {
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    api
      .getAdminDashboard()
      .then((res) => {
        if (isMounted) setData(res as DashboardData);
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
      <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>

      <div className="grid gap-6 md:grid-cols-3">
        <div className="rounded-lg bg-white p-6 shadow">
          <p className="text-sm font-medium text-gray-600">Total Inversores</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">{data.data.investorCount}</p>
        </div>
        <div className="rounded-lg bg-white p-6 shadow">
          <p className="text-sm font-medium text-gray-600">AUM Total</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">
            {formatCurrencyAR(data.data.totalAum)}
          </p>
        </div>
        <div className="rounded-lg bg-white p-6 shadow">
          <p className="text-sm font-medium text-gray-600">Solicitudes Pendientes</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">{data.data.pendingRequestCount}</p>
        </div>
      </div>
    </div>
  );
};
