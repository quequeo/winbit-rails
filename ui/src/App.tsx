import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AdminLayout } from './components/layout/AdminLayout';
import { DashboardPage } from './pages/DashboardPage';
import { InvestorsPage } from './pages/InvestorsPage';
import { EditInvestorPage } from './pages/EditInvestorPage';
import { RequestsPage } from './pages/RequestsPage';
import { AdminsPage } from './pages/AdminsPage';
import { EditAdminPage } from './pages/EditAdminPage';
import { SettingsPage } from './pages/SettingsPage';
import { ActivityLogsPage } from './pages/ActivityLogsPage';
import { TradingFeesPage } from './pages/TradingFeesPage';
import { TradingFeesHistoryPage } from './pages/TradingFeesHistoryPage';
import { DailyOperatingResultsPage } from './pages/DailyOperatingResultsPage';
import { OperatingHistoryPage } from './pages/OperatingHistoryPage';
import { DepositOptionsPage } from './pages/DepositOptionsPage';
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
          <Route path="/trading-fees" element={<TradingFeesPage />} />
          <Route path="/trading-fees/history" element={<TradingFeesHistoryPage />} />
          <Route path="/deposit-options" element={<DepositOptionsPage />} />
          <Route path="/admins" element={<AdminsPage />} />
          <Route path="/admins/:id/edit" element={<EditAdminPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/activity" element={<ActivityLogsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
