import { useEffect, useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { api } from '../../lib/api';

const linkBase =
  'border-b-2 border-transparent px-1 py-4 text-sm font-medium text-gray-700 hover:border-[#58b098] hover:text-[#58b098]';

type AdminSession = {
  data: {
    email: string;
    superadmin: boolean;
  };
};

export const AdminLayout = () => {
  const navigate = useNavigate();
  const [isCheckingSession, setIsCheckingSession] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [sessionEmail, setSessionEmail] = useState<string | null>(null);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    let isMounted = true;
    api
      .getAdminSession()
      .then((res) => {
        const r = res as AdminSession;
        if (isMounted) setSessionEmail(r?.data?.email || null);
      })
      .catch((e) => {
        if (!isMounted) return;
        if (e?.message === 'Unauthorized') {
          navigate('/login', { replace: true });
          return;
        }
        setError(e?.message || 'Error');
      })
      .finally(() => {
        if (isMounted) setIsCheckingSession(false);
      });

    return () => {
      isMounted = false;
    };
  }, [navigate]);

  const onLogout = async () => {
    try {
      await api.signOut();
    } finally {
      setMobileMenuOpen(false);
      navigate('/login', { replace: true });
    }
  };

  if (isCheckingSession) return <div className="p-6 text-gray-600">Cargando...</div>;
  if (error) return <div className="p-6 text-red-600">{error}</div>;

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="flex items-center justify-between px-4 py-4 md:px-6">
          <div>
            <h1 className="text-2xl font-bold text-[#58b098]">Winbit Admin v1.0.0</h1>
            <p className="text-sm text-gray-600">{sessionEmail || '—'}</p>
          </div>

          <div className="flex items-center gap-2">
            {/* Desktop logout (right) */}
            <button
              type="button"
              onClick={onLogout}
              className="hidden md:inline-flex rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
              aria-label="Cerrar sesión"
              title="Cerrar sesión"
            >
              Cerrar sesión
            </button>

            {/* Mobile hamburger (right) */}
            <button
              type="button"
              className="md:hidden inline-flex items-center justify-center rounded-lg border border-gray-200 bg-white p-2 text-gray-700 hover:bg-gray-50"
              aria-label="Abrir menú"
              onClick={() => setMobileMenuOpen((v) => !v)}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M4 6h16M4 12h16M4 18h16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
            </button>
          </div>
        </div>

        {/* Desktop nav */}
        <nav className="hidden md:block border-t border-gray-200 bg-white px-6">
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
              to="/requests"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Solicitudes
            </NavLink>
            <NavLink
              to="/daily-operating"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Operativa diaria
            </NavLink>
            <NavLink
              to="/operating-history"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Historial de Operativas
            </NavLink>
            <NavLink
              to="/trading-fees"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Comisiones
            </NavLink>
            <NavLink
              to="/trading-fees/history"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Historial Fees
            </NavLink>
            <NavLink
              to="/deposit-options"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Depósitos
            </NavLink>
            <NavLink
              to="/admins"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Admins
            </NavLink>
            <NavLink
              to="/settings"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Configuración
            </NavLink>
            <NavLink
              to="/activity"
              className={({ isActive }) =>
                isActive ? `${linkBase} border-[#58b098] text-[#58b098]` : linkBase
              }
            >
              Actividad
            </NavLink>
          </div>
        </nav>

        {/* Mobile menu */}
        {mobileMenuOpen ? (
          <nav className="md:hidden border-t border-gray-200 bg-white px-4 py-3">
            <div className="flex flex-col gap-2">
              <NavLink
                to="/dashboard"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Dashboard
              </NavLink>
              <NavLink
                to="/investors"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Inversores
              </NavLink>
              <NavLink
                to="/requests"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Solicitudes
              </NavLink>
              <NavLink
                to="/trading-fees"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Comisiones
              </NavLink>
              <NavLink
                to="/trading-fees/history"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Historial Fees
              </NavLink>
              <NavLink
                to="/deposit-options"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Depósitos
              </NavLink>
              <NavLink
                to="/admins"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Admins
              </NavLink>
              <NavLink
                to="/settings"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Configuración
              </NavLink>
              <NavLink
                to="/activity"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? 'rounded-lg bg-[#58b098]/10 px-3 py-2 text-sm font-medium text-[#58b098]'
                    : 'rounded-lg px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50'
                }
              >
                Actividad
              </NavLink>

              <div className="my-1 h-px bg-gray-200" />

              <button
                type="button"
                onClick={onLogout}
                className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-left text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                Cerrar sesión
              </button>
            </div>
          </nav>
        ) : null}
      </header>

      <main className="container mx-auto px-6 py-8">
        <Outlet />
      </main>
    </div>
  );
};
