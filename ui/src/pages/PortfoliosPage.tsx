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

  const investors = (data?.data || []) as any[];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Portfolios</h1>
      </div>

      {/* Mobile: cards */}
      <div className="grid gap-3 px-1 md:hidden">
        {investors.map((inv: any) => (
          <div key={inv.id} className="w-full overflow-hidden rounded-lg bg-white p-4 shadow">
            <div className="min-w-0">
              <p className="truncate text-sm font-semibold text-gray-900">{inv.name}</p>
              <p className="truncate mt-1 text-sm text-gray-600">{inv.email}</p>
            </div>

            <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
              <div>
                <p className="text-xs text-gray-500">Capital Actual</p>
                <p className="mt-1 font-mono font-semibold text-gray-900">
                  ${(inv.portfolio?.current_balance ?? 0).toLocaleString('en-US', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  })}
                </p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Total Invertido</p>
                <p className="mt-1 font-mono font-semibold text-gray-900">
                  ${(inv.portfolio?.total_invested ?? 0).toLocaleString('en-US', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  })}
                </p>
              </div>
            </div>

            <div className="mt-4">
              <Link to={`/portfolios/${inv.id}`}>
                <Button size="sm" className="w-full">
                  Editar Portfolio
                </Button>
              </Link>
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
                <th className="py-2 text-right">Capital Actual</th>
                <th className="py-2 text-right">Total Invertido</th>
                <th className="py-2 text-center">Acciones</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {investors.map((inv: any) => (
                <tr key={inv.id} className="text-sm">
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
                  <td className="py-2 text-center">
                    <Link to={`/portfolios/${inv.id}`}>
                      <Button size="sm" className="px-2 py-1 text-xs">
                        Editar
                      </Button>
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
