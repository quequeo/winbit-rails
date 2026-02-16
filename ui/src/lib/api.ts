const DEFAULT_BASE_URL = import.meta.env.PROD ? '' : 'http://localhost:3000';

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || DEFAULT_BASE_URL;

async function request(path: string, options?: RequestInit) {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(options?.headers || {}),
    },
  });

  if (!res.ok) {
    // Devise returns 401/403 when not authenticated/authorized.
    if (res.status === 401) throw new Error('Unauthorized');
    if (res.status === 403) throw new Error('Forbidden');

    const contentType = res.headers.get('content-type') || '';
    const body = contentType.includes('application/json') ? JSON.stringify(await res.json()) : await res.text();
    throw new Error(body || `Request failed: ${res.status}`);
  }

  if (res.status === 204) {
    return null;
  }

  const contentType = res.headers.get('content-type') || '';
  if (!contentType.includes('application/json')) {
    const text = await res.text();
    return text ? { data: text } : null;
  }

  // Avoid "Unexpected end of JSON input" on empty bodies.
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

export const api = {
  getAdminSession: () => request('/api/admin/session'),
  getAdminDashboard: (params?: { days?: number }) => {
    const qs = new URLSearchParams();
    if (params?.days !== undefined) qs.set('days', params.days.toString());
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/dashboard${suffix}`);
  },
  getAdminInvestors: (params?: { sort_by?: string; sort_order?: string }) => {
    const qs = new URLSearchParams();
    if (params?.sort_by) qs.set('sort_by', params.sort_by);
    if (params?.sort_order) qs.set('sort_order', params.sort_order);
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/investors${suffix}`);
  },
  signOut: () => request('/users/sign_out', { method: 'DELETE' }),
  getAdminRequests: (params?: { status?: string; type?: string }) => {
    const qs = new URLSearchParams();
    if (params?.status) qs.set('status', params.status);
    if (params?.type) qs.set('type', params.type);
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/requests${suffix}`);
  },
  createRequest: (body: { investor_id: string; request_type: string; method: string; amount: number; network?: string; status?: string; requested_at?: string; processed_at?: string }) =>
    request('/api/admin/requests', { method: 'POST', body: JSON.stringify(body) }),
  updateRequest: (id: string, body: { investor_id: string; request_type: string; method: string; amount: number; network?: string; status?: string }) =>
    request(`/api/admin/requests/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteRequest: (id: string) => request(`/api/admin/requests/${id}`, { method: 'DELETE' }),
  approveRequest: (id: string, body?: { processed_at?: string }) =>
    request(`/api/admin/requests/${id}/approve`, { method: 'POST', body: JSON.stringify(body || {}) }),
  rejectRequest: (id: string) => request(`/api/admin/requests/${id}/reject`, { method: 'POST' }),
  getAdminAdmins: () => request('/api/admin/admins'),
  createAdmin: (body: { email: string; name?: string; role: 'ADMIN' | 'SUPERADMIN' }) =>
    request('/api/admin/admins', { method: 'POST', body: JSON.stringify(body) }),
  updateAdmin: (id: string, body: { email: string; name?: string; role: 'ADMIN' | 'SUPERADMIN' }) =>
    request(`/api/admin/admins/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteAdmin: (id: string) => request(`/api/admin/admins/${id}`, { method: 'DELETE' }),
  createInvestor: (body: { email: string; name: string }) =>
    request('/api/admin/investors', { method: 'POST', body: JSON.stringify(body) }),
  updateInvestor: (id: string, body: { email: string; name: string; trading_fee_frequency?: 'QUARTERLY' | 'SEMESTRAL' | 'ANNUAL' }) =>
    request(`/api/admin/investors/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteInvestor: (id: string) => request(`/api/admin/investors/${id}`, { method: 'DELETE' }),
  toggleInvestorStatus: (id: string) => request(`/api/admin/investors/${id}/toggle_status`, { method: 'POST' }),
  applyReferralCommission: (
    investorId: string,
    body: { amount: number; applied_at?: string }
  ) => request(`/api/admin/investors/${investorId}/referral_commissions`, { method: 'POST', body: JSON.stringify(body) }),
  getAdminSettings: () => request('/api/admin/settings'),
  updateAdminSettings: (body: { investor_notifications_enabled?: boolean; investor_email_whitelist?: string[] | string }) =>
    request('/api/admin/settings', { method: 'PATCH', body: JSON.stringify(body) }),
  getActivityLogs: (params?: { page?: number; per_page?: number; user_id?: string; filter_action?: string }) => {
    const qs = new URLSearchParams();
    if (params?.page) qs.set('page', params.page.toString());
    if (params?.per_page) qs.set('per_page', params.per_page.toString());
    if (params?.user_id) qs.set('user_id', params.user_id);
    if (params?.filter_action) qs.set('filter_action', params.filter_action);
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/activity_logs${suffix}`);
  },
  // Operativa diaria
  getDailyOperatingResults: (params?: { page?: number; per_page?: number }) => {
    const qs = new URLSearchParams();
    if (params?.page) qs.set('page', params.page.toString());
    if (params?.per_page) qs.set('per_page', params.per_page.toString());
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/daily_operating_results${suffix}`);
  },
  getDailyOperatingMonthlySummary: (params?: { months?: number }) => {
    const qs = new URLSearchParams();
    if (params?.months) qs.set('months', params.months.toString());
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/daily_operating_results/monthly_summary${suffix}`);
  },
  getDailyOperatingByMonth: (params: { month: string }) => {
    const qs = new URLSearchParams();
    qs.set('month', params.month);
    return request(`/api/admin/daily_operating_results/by_month?${qs.toString()}`);
  },
  previewDailyOperatingResult: (params: { date: string; percent: number; notes?: string }) => {
    const qs = new URLSearchParams();
    qs.set('date', params.date);
    qs.set('percent', params.percent.toString());
    if (params.notes) qs.set('notes', params.notes);
    return request(`/api/admin/daily_operating_results/preview?${qs.toString()}`);
  },
  createDailyOperatingResult: (body: { date: string; percent: number; notes?: string }) =>
    request('/api/admin/daily_operating_results', { method: 'POST', body: JSON.stringify(body) }),
  // Trading Fees
  getTradingFees: (params?: { investor_id?: string }) => {
    const qs = new URLSearchParams();
    if (params?.investor_id) qs.set('investor_id', params.investor_id);
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/trading_fees${suffix}`);
  },
  getTradingFeesSummary: (params?: { period_start?: string; period_end?: string }) => {
    const qs = new URLSearchParams();
    if (params?.period_start) qs.set('period_start', params.period_start);
    if (params?.period_end) qs.set('period_end', params.period_end);
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/trading_fees/investors_summary${suffix}`);
  },
  calculateTradingFee: (params: { investor_id: string; fee_percentage: number; period_start?: string; period_end?: string }) => {
    const qs = new URLSearchParams();
    qs.set('investor_id', params.investor_id);
    qs.set('fee_percentage', params.fee_percentage.toString());
    if (params.period_start) qs.set('period_start', params.period_start);
    if (params.period_end) qs.set('period_end', params.period_end);
    return request(`/api/admin/trading_fees/calculate?${qs.toString()}`);
  },
  applyTradingFee: (body: { investor_id: string; fee_percentage: number; notes?: string; period_start?: string; period_end?: string }) =>
    request('/api/admin/trading_fees', { method: 'POST', body: JSON.stringify(body) }),
  updateTradingFee: (id: string, body: { fee_percentage: number; notes?: string }) =>
    request(`/api/admin/trading_fees/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteTradingFee: (id: string) => request(`/api/admin/trading_fees/${id}`, { method: 'DELETE' }),

};
