import { useEffect, useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { api } from "../../lib/api";

const linkBase =
  "border-b-2 border-transparent px-1 py-4 text-sm font-medium text-t-muted hover:border-primary hover:text-primary";

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
        if (e?.message === "Unauthorized") {
          navigate("/login", { replace: true });
          return;
        }
        setError(e?.message || "Error");
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
      navigate("/login", { replace: true });
    }
  };

  if (isCheckingSession)
    return <div className="p-6 text-t-muted">Cargando...</div>;
  if (error) return <div className="p-6 text-error">{error}</div>;

  return (
    <div className="min-h-screen bg-dark-bg">
      <header className="bg-dark-card border-b border-b-default">
        <div className="flex items-center justify-between px-4 py-4 md:px-6">
          <div>
            <h1 className="text-2xl font-bold text-primary">
              Winbit Admin v1.0.0
            </h1>
            <p className="text-sm text-t-muted">{sessionEmail || "—"}</p>
          </div>

          <div className="flex items-center gap-2">
            {/* Desktop logout (right) */}
            <button
              type="button"
              onClick={onLogout}
              className="hidden md:inline-flex rounded-lg border border-b-default bg-dark-section px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
              aria-label="Cerrar sesión"
              title="Cerrar sesión"
            >
              Cerrar sesión
            </button>

            {/* Mobile hamburger (right) */}
            <button
              type="button"
              className="md:hidden inline-flex items-center justify-center rounded-lg border border-b-default bg-dark-section p-2 text-t-muted hover:bg-primary-dim"
              aria-label="Abrir menú"
              onClick={() => setMobileMenuOpen((v) => !v)}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path
                  d="M4 6h16M4 12h16M4 18h16"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                />
              </svg>
            </button>
          </div>
        </div>

        {/* Desktop nav */}
        <nav className="hidden md:block border-t border-b-default bg-dark-card px-6">
          <div className="flex space-x-8">
            <NavLink
              to="/dashboard"
              className={({ isActive }) =>
                isActive
                  ? `${linkBase} border-primary text-primary`
                  : linkBase
              }
            >
              Dashboard
            </NavLink>
            <NavLink
              to="/investors"
              className={({ isActive }) =>
                isActive
                  ? `${linkBase} border-primary text-primary`
                  : linkBase
              }
            >
              Inversores
            </NavLink>
            <NavLink
              to="/requests"
              className={({ isActive }) =>
                isActive
                  ? `${linkBase} border-primary text-primary`
                  : linkBase
              }
            >
              Solicitudes
            </NavLink>
            <NavLink
              to="/operativa"
              className={({ isActive }) =>
                isActive
                  ? `${linkBase} border-primary text-primary`
                  : linkBase
              }
            >
              Operativa
            </NavLink>
            <NavLink
              to="/trading-fees"
              className={({ isActive }) =>
                isActive
                  ? `${linkBase} border-primary text-primary`
                  : linkBase
              }
            >
              Comisiones
            </NavLink>
            <NavLink
              to="/admins"
              className={({ isActive }) =>
                isActive
                  ? `${linkBase} border-primary text-primary`
                  : linkBase
              }
            >
              Admins
            </NavLink>
            <NavLink
              to="/activity"
              className={({ isActive }) =>
                isActive
                  ? `${linkBase} border-primary text-primary`
                  : linkBase
              }
            >
              Actividad
            </NavLink>
          </div>
        </nav>

        {/* Mobile menu */}
        {mobileMenuOpen ? (
          <nav className="md:hidden border-t border-b-default bg-dark-card px-4 py-3">
            <div className="flex flex-col gap-2">
              <NavLink
                to="/dashboard"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? "rounded-lg bg-primary-dim px-3 py-2 text-sm font-medium text-primary"
                    : "rounded-lg px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
                }
              >
                Dashboard
              </NavLink>
              <NavLink
                to="/investors"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? "rounded-lg bg-primary-dim px-3 py-2 text-sm font-medium text-primary"
                    : "rounded-lg px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
                }
              >
                Inversores
              </NavLink>
              <NavLink
                to="/requests"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? "rounded-lg bg-primary-dim px-3 py-2 text-sm font-medium text-primary"
                    : "rounded-lg px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
                }
              >
                Solicitudes
              </NavLink>
              <NavLink
                to="/operativa"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? "rounded-lg bg-primary-dim px-3 py-2 text-sm font-medium text-primary"
                    : "rounded-lg px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
                }
              >
                Operativa
              </NavLink>
              <NavLink
                to="/trading-fees"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? "rounded-lg bg-primary-dim px-3 py-2 text-sm font-medium text-primary"
                    : "rounded-lg px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
                }
              >
                Comisiones
              </NavLink>
              <NavLink
                to="/admins"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? "rounded-lg bg-primary-dim px-3 py-2 text-sm font-medium text-primary"
                    : "rounded-lg px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
                }
              >
                Admins
              </NavLink>
              <NavLink
                to="/activity"
                onClick={() => setMobileMenuOpen(false)}
                className={({ isActive }) =>
                  isActive
                    ? "rounded-lg bg-primary-dim px-3 py-2 text-sm font-medium text-primary"
                    : "rounded-lg px-3 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim"
                }
              >
                Actividad
              </NavLink>

              <div className="my-1 h-px bg-b-default" />

              <button
                type="button"
                onClick={onLogout}
                className="rounded-lg border border-b-default bg-dark-section px-3 py-2 text-left text-sm font-medium text-t-muted hover:bg-primary-dim"
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
