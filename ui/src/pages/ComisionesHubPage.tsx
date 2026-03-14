import { useSearchParams } from "react-router-dom";
import { TradingFeesPage } from "./TradingFeesPage";
import { ReferralCommissionsPage } from "./ReferralCommissionsPage";
import { TradingFeesHistoryPage } from "./TradingFeesHistoryPage";

type Tab = "periodo" | "referido" | "historial";

const TABS: { id: Tab; label: string }[] = [
  { id: "periodo", label: "Comisiones por período" },
  { id: "referido", label: "Comisiones por referido" },
  { id: "historial", label: "Historial de Comisiones" },
];

export const ComisionesHubPage = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = (searchParams.get("tab") as Tab) || "periodo";

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

      {activeTab === "periodo" && <TradingFeesPage />}
      {activeTab === "referido" && <ReferralCommissionsPage />}
      {activeTab === "historial" && <TradingFeesHistoryPage />}
    </div>
  );
};
