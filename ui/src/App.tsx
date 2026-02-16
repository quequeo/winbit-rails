import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AdminLayout } from './components/layout/AdminLayout';
import { DashboardPage } from './pages/DashboardPage';
import { InvestorsPage } from './pages/InvestorsPage';
import { RequestsPage } from './pages/RequestsPage';
import { AdminsPage } from './pages/AdminsPage';
import { SettingsPage } from './pages/SettingsPage';
import { ActivityLogsPage } from './pages/ActivityLogsPage';
import { TradingFeesPage } from './pages/TradingFeesPage';
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
          <Route path="/requests" element={<RequestsPage />} />
          <Route path="/daily-operating" element={<DailyOperatingResultsPage />} />
          <Route path="/operating-history" element={<OperatingHistoryPage />} />
          <Route path="/trading-fees" element={<TradingFeesPage />} />
          <Route path="/admins" element={<AdminsPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/activity" element={<ActivityLogsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
