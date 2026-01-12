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
  getAdminDashboard: () => request('/api/admin/dashboard'),
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
  createRequest: (body: { investor_id: string; request_type: string; method: string; amount: number; network?: string; status?: string }) =>
    request('/api/admin/requests', { method: 'POST', body: JSON.stringify(body) }),
  updateRequest: (id: string, body: { investor_id: string; request_type: string; method: string; amount: number; network?: string; status?: string }) =>
    request(`/api/admin/requests/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteRequest: (id: string) => request(`/api/admin/requests/${id}`, { method: 'DELETE' }),
  approveRequest: (id: string) => request(`/api/admin/requests/${id}/approve`, { method: 'POST' }),
  rejectRequest: (id: string) => request(`/api/admin/requests/${id}/reject`, { method: 'POST' }),
  getAdminPortfolios: () => request('/api/admin/portfolios'),
  updatePortfolio: (investorId: string, body: any) => request(`/api/admin/portfolios/${investorId}`, { method: 'PATCH', body: JSON.stringify(body) }),
  getAdminAdmins: () => request('/api/admin/admins'),
  createAdmin: (body: { email: string; name?: string; role: 'ADMIN' | 'SUPERADMIN' }) =>
    request('/api/admin/admins', { method: 'POST', body: JSON.stringify(body) }),
  updateAdmin: (id: string, body: { email: string; name?: string; role: 'ADMIN' | 'SUPERADMIN' }) =>
    request(`/api/admin/admins/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteAdmin: (id: string) => request(`/api/admin/admins/${id}`, { method: 'DELETE' }),
  createInvestor: (body: { email: string; name: string }) =>
    request('/api/admin/investors', { method: 'POST', body: JSON.stringify(body) }),
  updateInvestor: (id: string, body: { email: string; name: string }) =>
    request(`/api/admin/investors/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteInvestor: (id: string) => request(`/api/admin/investors/${id}`, { method: 'DELETE' }),
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
};
