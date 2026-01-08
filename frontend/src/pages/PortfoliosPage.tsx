import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';

export const PortfoliosPage = () => {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    api
      .getAdminPortfolios()
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
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Portfolios</h1>
        <p className="text-gray-600 mt-1">
          Haz clic en "Editar Portfolio" para modificar los datos de inversión de cada inversor
        </p>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead>
              <tr className="text-left text-sm text-gray-500">
                <th className="py-2">Código</th>
                <th className="py-2">Nombre</th>
                <th className="py-2">Email</th>
                <th className="py-2 text-right">Capital Actual</th>
                <th className="py-2 text-right">Total Invertido</th>
                <th className="py-2 text-right">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {data.data.map((inv: any) => (
                <tr key={inv.id} className="text-sm">
                  <td className="py-2 font-mono">{inv.code}</td>
                  <td className="py-2 font-medium">{inv.name}</td>
                  <td className="py-2 text-gray-600">{inv.email}</td>
                  <td className="py-2 text-right">
                    ${(inv.portfolio?.current_balance ?? 0).toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </td>
                  <td className="py-2 text-right">
                    ${(inv.portfolio?.total_invested ?? 0).toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </td>
                  <td className="py-2 text-right">
                    <Link to={`/portfolios/${inv.id}`}>
                      <Button size="sm">Editar Portfolio</Button>
                    </Link>
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
