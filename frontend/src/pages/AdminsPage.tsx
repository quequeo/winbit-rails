import { useEffect, useState } from 'react';
import { api } from '../lib/api';

export const AdminsPage = () => {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    api
      .getAdminAdmins()
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

  const admins = (data?.data || []) as any[];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Admins</h1>
        <p className="text-gray-600 mt-1">Gestiona los usuarios que pueden acceder al panel.</p>
      </div>

      {/* Mobile: cards */}
      <div className="grid gap-3 md:hidden">
        {admins.map((a: any) => (
          <div key={a.id} className="rounded-lg bg-white p-4 shadow">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-gray-900">{a.email}</p>
                <p className="mt-1 text-sm text-gray-600">{a.name || '-'}</p>
              </div>
              <span
                className={`shrink-0 inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                  a.role === 'SUPERADMIN' ? 'bg-purple-100 text-purple-800' : 'bg-blue-100 text-blue-800'
                }`}
              >
                {a.role === 'SUPERADMIN' ? 'Super Admin' : 'Admin'}
              </span>
            </div>
            <div className="mt-3 text-xs text-gray-500">
              Creado: {new Date(a.created_at || a.createdAt).toLocaleDateString('es-AR')}
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
                <th className="py-2">Email</th>
                <th className="py-2">Nombre</th>
                <th className="py-2">Rol</th>
                <th className="py-2">Fecha</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {admins.map((a: any) => (
                <tr key={a.id} className="text-sm">
                  <td className="py-2 font-medium">{a.email}</td>
                  <td className="py-2">{a.name || '-'}</td>
                  <td className="py-2">
                    <span
                      className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                        a.role === 'SUPERADMIN'
                          ? 'bg-purple-100 text-purple-800'
                          : 'bg-blue-100 text-blue-800'
                      }`}
                    >
                      {a.role === 'SUPERADMIN' ? 'Super Admin' : 'Admin'}
                    </span>
                  </td>
                  <td className="py-2 text-gray-600">
                    {new Date(a.created_at || a.createdAt).toLocaleDateString('es-AR')}
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
