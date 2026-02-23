import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AdminLayout } from './components/layout/AdminLayout';
import { DashboardPage } from './pages/DashboardPage';
import { InvestorsPage } from './pages/InvestorsPage';
import { EditInvestorPage } from './pages/EditInvestorPage';
import { RequestsPage } from './pages/RequestsPage';
import { AdminsHubPage } from './pages/AdminsHubPage';
import { EditAdminPage } from './pages/EditAdminPage';
import { ActivityLogsPage } from './pages/ActivityLogsPage';
import { ComisionesHubPage } from './pages/ComisionesHubPage';
import { TradingFeesHistoryPage } from './pages/TradingFeesHistoryPage';
import { DailyOperatingResultsPage } from './pages/DailyOperatingResultsPage';
import { OperatingHistoryPage } from './pages/OperatingHistoryPage';
import { LoginPage } from './pages/LoginPage';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />

        <Route element={<AdminLayout />}>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/investors" element={<InvestorsPage />} />
          <Route path="/investors/:id/edit" element={<EditInvestorPage />} />
          <Route path="/requests" element={<RequestsPage />} />
          <Route path="/daily-operating" element={<DailyOperatingResultsPage />} />
          <Route path="/operating-history" element={<OperatingHistoryPage />} />
          <Route path="/trading-fees" element={<ComisionesHubPage />} />
          <Route path="/trading-fees/history" element={<TradingFeesHistoryPage />} />
          <Route path="/admins" element={<AdminsHubPage />} />
          <Route path="/admins/:id/edit" element={<EditAdminPage />} />
          {/* Legacy redirects */}
          <Route path="/deposit-options" element={<Navigate to="/admins?tab=depositos" replace />} />
          <Route path="/settings" element={<Navigate to="/admins?tab=configuracion" replace />} />
          <Route path="/activity" element={<ActivityLogsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
