import { NavLink, Outlet } from 'react-router-dom';

const linkBase =
  'border-b-2 border-transparent px-1 py-4 text-sm font-medium text-gray-700 hover:border-[#58b098] hover:text-[#58b098]';

export const AdminLayout = () => {
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="flex items-center justify-between px-6 py-4">
          <div>
            <h1 className="text-2xl font-bold text-[#58b098]">Winbit Admin</h1>
            <p className="text-sm text-gray-600">Admin</p>
          </div>
        </div>
        <nav className="border-t border-gray-200 bg-white px-6">
          <div className="flex space-x-8">
            <NavLink
              to="/dashboard"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Dashboard
            </NavLink>
            <NavLink
              to="/investors"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Inversores
            </NavLink>
            <NavLink
              to="/portfolios"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Portfolios
            </NavLink>
            <NavLink
              to="/requests"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Solicitudes
            </NavLink>
            <NavLink
              to="/admins"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Admins
            </NavLink>
          </div>
        </nav>
      </header>

      <main className="container mx-auto px-6 py-8">
        <Outlet />
      </main>
    </div>
  );
};
