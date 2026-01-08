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

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Admins</h1>
        <p className="text-gray-600 mt-1">Gestiona los usuarios que pueden acceder al panel.</p>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
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
              {data.data.map((a: any) => (
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
