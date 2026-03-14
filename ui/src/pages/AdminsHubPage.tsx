import { useSearchParams } from "react-router-dom";
import { AdminsPage } from "./AdminsPage";
import { SettingsPage } from "./SettingsPage";
import { DepositOptionsPage } from "./DepositOptionsPage";

type Tab = "usuarios" | "configuracion" | "depositos";

const TABS: { id: Tab; label: string }[] = [
  { id: "usuarios", label: "Usuarios" },
  { id: "configuracion", label: "Configuración" },
  { id: "depositos", label: "Métodos de Depósito" },
];

export const AdminsHubPage = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = (searchParams.get("tab") as Tab) || "usuarios";

  const setTab = (tab: Tab) => {
    setSearchParams({ tab }, { replace: true });
  };

  return (
    <div>
      <div className="mb-6 border-b border-b-default">
        <nav className="-mb-px flex space-x-6">
          {TABS.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setTab(tab.id)}
              className={
                activeTab === tab.id
                  ? "border-b-2 border-primary pb-3 text-sm font-semibold text-primary"
                  : "border-b-2 border-transparent pb-3 text-sm font-medium text-t-dim hover:border-b-default hover:text-t-muted"
              }
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>

      {activeTab === "usuarios" && <AdminsPage />}
      {activeTab === "configuracion" && <SettingsPage />}
      {activeTab === "depositos" && <DepositOptionsPage />}
    </div>
  );
};
